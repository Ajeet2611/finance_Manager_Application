import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart'; // Assume this service exists

// _app_id is a global variable provided by the Canvas Environment.
const String _appId = 'your_app_id';

class BillSetupScreen extends StatefulWidget {
  const BillSetupScreen({super.key});

  @override
  State<BillSetupScreen> createState() => _BillSetupScreenState();
}

class _BillSetupScreenState extends State<BillSetupScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _billNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  int? _selectedDueDate;
  String _frequency = 'Monthly';

  bool _receiveReminders = true;

  static const String _billCollectionName = 'user_bills';

  @override
  void dispose() {
    _billNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Firestore Collection Path Getter
  CollectionReference<Map<String, dynamic>> _getBillCollection() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated.");
    }

    // Get APP_ID from the Canvas Environment
    const String appId = String.fromEnvironment('APP_ID', defaultValue: _appId);

    // Path compliant with Firestore security rules
    return _firestore
        .collection('artifacts')
        .doc(appId)
        .collection('users')
        .doc(user.uid)
        .collection(_billCollectionName);
  }

  // --- Helper: Calculate Next Due Date ---
  DateTime _calculateNextDueDate(
      int dayOfMonth, String frequency, Timestamp? lastPaidTs) {
    // Start from the last payment date or the day before now
    DateTime dateToStartFrom =
        lastPaidTs?.toDate() ?? DateTime.now().subtract(const Duration(days: 1));
    DateTime now = DateTime.now();

    DateTime nextDueDate;

    if (frequency == 'Monthly') {
      // If the due day of this month has passed since the last payment, go to the next month
      if (dateToStartFrom.day >= dayOfMonth) {
        // Go to the next month
        nextDueDate = DateTime(
            dateToStartFrom.year, dateToStartFrom.month + 1, dayOfMonth);
      } else {
        // Otherwise, the due day is in the current month
        nextDueDate =
            DateTime(dateToStartFrom.year, dateToStartFrom.month, dayOfMonth);
      }

      // Ensure the due date is not before the current time (today or future)
      if (nextDueDate.isBefore(now.subtract(const Duration(days: 1)))) {
        // If it's in the past (possibly lastPaidTs was very old), set it to the current or next month
        DateTime currentMonthDue = DateTime(now.year, now.month, dayOfMonth);
        if (currentMonthDue.isBefore(now)) {
          nextDueDate = DateTime(now.year, now.month + 1, dayOfMonth);
        } else {
          nextDueDate = currentMonthDue;
        }
      }
    } else if (frequency == 'Annually') {
      // For an annual bill, we consider the month the bill was added (if no lastPaidTs)
      // or the last payment was made, as the due month.
      int dueMonth = (lastPaidTs?.toDate() ?? now).month;

      // Due date for the next year
      nextDueDate =
          DateTime(dateToStartFrom.year + 1, dueMonth, dayOfMonth);

      // If this date is in the past, advance it one more year
      if (nextDueDate.isBefore(now.subtract(const Duration(days: 1)))) {
        nextDueDate = DateTime(now.year + 1, dueMonth, dayOfMonth);
      }

      // If the due date is still in the future for this year (e.g., the bill was added last year)
      DateTime currentYearDue = DateTime(now.year, dueMonth, dayOfMonth);
      if (currentYearDue.isAfter(now)) {
        nextDueDate = currentYearDue;
      }
    } else {
      // Default to Monthly
      nextDueDate =
          DateTime(dateToStartFrom.year, dateToStartFrom.month + 1, dayOfMonth);
    }

    // Since DayOfMonth is restricted to 1-28, we can generally skip month overflow checks.
    return nextDueDate;
  }
  // --- Helper End ---

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Please log in.');
      return;
    }

    if (_selectedDueDate == null) {
      _showSnackBar('Please select the bill due date (day).');
      return;
    }

    final double amount = double.tryParse(_amountController.text) ?? 0.0;
    final dayOfMonth = _selectedDueDate!;
    final billName = _billNameController.text.trim();

    try {
      final docRef = await _getBillCollection().add({
        'name': billName,
        'amount': amount,
        'dayOfMonth': dayOfMonth,
        'frequency': _frequency,
        'isActive': true,
        'receiveReminders': _receiveReminders,
        'lastPaidDate': null, // null on first addition
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_receiveReminders) {
        // Use a stable hash code of the Document ID for the Notification ID
        final notificationId = docRef.id.hashCode.abs();

        // Ask NotificationService to schedule for the first due date
        await NotificationService.scheduleBillNotification(
          id: notificationId,
          title: billName,
          amount: amount,
          frequency: _frequency,
          dayOfMonth: dayOfMonth,
          billId: docRef.id,
        );
        _showSnackBar('Bill added successfully and reminders are set! 🎉',
            isError: false);
      } else {
        _showSnackBar('Bill added successfully.', isError: false);
      }

      _resetForm();
    } catch (e) {
      debugPrint("Error saving bill: $e");
      _showSnackBar('Error adding bill: $e');
    }
  }

  // --- Logic to reschedule reminder after payment ---
  Future<void> _markAsPaid(
      String billDocId,
      String billName,
      double amount,
      String frequency,
      int dayOfMonth,
      ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Update the last paid date in Firestore
      await _getBillCollection().doc(billDocId).update({
        'lastPaidDate': Timestamp.now(),
      });

      // 2. Retrieve current bill data to check if reminders are active
      final docSnapshot = await _getBillCollection().doc(billDocId).get();
      final data = docSnapshot.data();
      final bool receiveReminders = data?['receiveReminders'] ?? false;

      final notificationId = billDocId.hashCode.abs();
      // 3. Cancel the existing reminder upon payment
      await NotificationService.cancelNotification(notificationId);

      // 4. If the reminder is active, reschedule it for the next cycle.
      if (receiveReminders) {
        // Now calculate the new nextDueDate
        // Note: We use Timestamp.now() as the starting point for the next due date calculation
        final DateTime nextDueDate =
        _calculateNextDueDate(dayOfMonth, frequency, Timestamp.now());

        await NotificationService.scheduleBillNotification(
          id: notificationId,
          title: billName,
          amount: amount,
          frequency: frequency,
          dayOfMonth: dayOfMonth,
          billId: billDocId,
          // Passing dayOfMonth and frequency allows the service to calculate the exact schedule
          // (The nextDueDate itself might be passed if the NotificationService supports exact DateTime scheduling)
        );
        _showSnackBar('Payment marked and next reminder set. ✅',
            isError: false);
      } else {
        _showSnackBar('Payment marked successfully.', isError: false);
      }
    } catch (e) {
      debugPrint("Error marking bill as paid: $e");
      _showSnackBar('Error marking payment: $e');
    }
  }

  Future<void> _deleteBill(String billDocId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _getBillCollection().doc(billDocId).delete();

      // Cancel the reminder when deleting the bill
      final notificationId = billDocId.hashCode.abs();
      await NotificationService.cancelNotification(notificationId);

      _showSnackBar('Bill deleted successfully. 🗑️', isError: false);
    } catch (e) {
      debugPrint("Error deleting bill: $e");
      _showSnackBar('Error deleting bill: $e');
    }
  }

  Stream<QuerySnapshot> _getBillsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    // Only show active bills
    return _getBillCollection()
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  void _resetForm() {
    _billNameController.clear();
    _amountController.clear();
    setState(() {
      _selectedDueDate = null;
      _frequency = 'Monthly';
      _receiveReminders = true;
    });
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.05), // Light background
      appBar: AppBar(
        title: const Text('Bill Reminder Manager',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Bill Setup Form ---
            _buildBillSetupForm(colorScheme),

            const SizedBox(height: 30),

            // --- Saved Bills Header ---
            Text(
              'Active Bill Reminders 🔔',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
            const Divider(height: 20),

            // --- Bill List (StreamBuilder) ---
            _buildBillList(colorScheme),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Bill Setup Form (Enhanced Design)
  Widget _buildBillSetupForm(ColorScheme colorScheme) {
    // Card with nice shadow and rounded corners
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.1), width: 1),
      ),
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set Up New Bill & Reminder 🔔',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 25),

              // 1. Bill Name
              _buildTextFormField(
                controller: _billNameController,
                label: 'Bill Name (e.g.: Electricity Bill, House Rent)',
                icon: Icons.receipt_long_rounded,
                colorScheme: colorScheme,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the bill name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // 2. Estimated Amount
              _buildTextFormField(
                controller: _amountController,
                label: 'Estimated Amount (₹)',
                icon: Icons.currency_rupee_rounded,
                colorScheme: colorScheme,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      double.tryParse(value) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // 3. Due Date (Day of Month) - 1 to 28
              DropdownButtonFormField<int>(
                decoration: _getDropdownInputDecoration(
                  label: 'Due Day of Month (1-28)',
                  icon: Icons.calendar_today_rounded,
                  colorScheme: colorScheme,
                ),
                value: _selectedDueDate,
                iconEnabledColor: colorScheme.primary, // Icon color
                items: List.generate(28, (index) => index + 1)
                    .map((day) => DropdownMenuItem(
                  value: day,
                  child: Text('Day $day of the Month',
                      style: TextStyle(color: colorScheme.onSurface)),
                ))
                    .toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedDueDate = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a due date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // 4. Frequency
              DropdownButtonFormField<String>(
                decoration: _getDropdownInputDecoration(
                  label: 'Frequency',
                  icon: Icons.repeat_rounded,
                  colorScheme: colorScheme,
                ),
                value: _frequency,
                iconEnabledColor: colorScheme.primary,
                items: ['Monthly', 'Annually']
                    .map((freq) => DropdownMenuItem(
                  value: freq,
                  child: Text(freq,
                      style: TextStyle(color: colorScheme.onSurface)),
                ))
                    .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _frequency = newValue!;
                  });
                },
              ),
              const SizedBox(height: 25),

              // 5. Reminder Toggle (Switch - Better Look)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05), // Light shade of primary color
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active_rounded,
                            color: colorScheme.primary, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          ' Bill Reminders',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _receiveReminders,
                      onChanged: (bool newValue) {
                        setState(() {
                          _receiveReminders = newValue;
                        });
                      },
                      activeColor: colorScheme.secondary,
                      inactiveThumbColor: colorScheme.surface,
                      inactiveTrackColor: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 6. Save Button (Animated/Elevated Button)
              ElevatedButton.icon(
                onPressed: _saveBill,
                icon: const Icon(Icons.add_task_rounded, size: 24),
                label: const Text('Add and Save Reminder',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 10,
                  shadowColor: colorScheme.primary.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for consistent TextFormField styling
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade800, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(0.05),
        prefixIcon: Icon(icon, color: colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: validator,
    );
  }

  // Helper for consistent DropdownFormField styling
  InputDecoration _getDropdownInputDecoration({
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      filled: true,
      fillColor: colorScheme.surfaceVariant.withOpacity(0.05),
      prefixIcon: Icon(icon, color: colorScheme.primary),
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    );
  }

  // Bill List (More Attractive and Informative Cards)
  Widget _buildBillList(ColorScheme colorScheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getBillsStream(),
      builder: (context, snapshot) {
        if (_auth.currentUser == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Please log in to view bills.',
                  style:
                  TextStyle(color: colorScheme.onBackground.withOpacity(0.7))),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint('Error loading bills: ${snapshot.error}');
          return Center(
              child: Text('Error loading data: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '🎉 No bills set up yet. Use the form above to set your first reminder!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colorScheme.onBackground.withOpacity(0.6),
                    fontStyle: FontStyle.italic),
              ),
            ),
          );
        }

        final bills = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final billDoc = bills[index];
            final data = billDoc.data() as Map<String, dynamic>;
            final String name = data['name'] ?? 'Untitled Bill';
            final double amount = (data['amount'] ?? 0.0).toDouble();
            final int dayOfMonth = data['dayOfMonth'] ?? 1;
            final String frequency = data['frequency'] ?? 'Monthly';
            final Timestamp? lastPaidTs = data['lastPaidDate'] as Timestamp?;
            final bool receiveReminders = data['receiveReminders'] ?? true;

            String lastPaidText = 'N/A';
            if (lastPaidTs != null) {
              lastPaidText = DateFormat('dd MMM yyyy').format(lastPaidTs.toDate());
            }

            // --- Next Due Date Calculation ---
            final DateTime nextDueDate =
            _calculateNextDueDate(dayOfMonth, frequency, lastPaidTs);
            final String nextDueDateText =
            DateFormat('dd MMM yyyy').format(nextDueDate);

            // Difference in days from today
            final int daysUntilDue =
                nextDueDate.difference(DateTime.now()).inDays + 1;

            // Status color determination logic
            Color statusColor;
            String dueDateMessage;
            if (!receiveReminders) {
              statusColor = Colors.grey.shade400;
              dueDateMessage = 'Reminders Inactive';
            } else if (daysUntilDue <= 0) {
              statusColor = Colors.red.shade600;
              dueDateMessage = 'Due Today or Overdue!';
            } else if (daysUntilDue <= 7) {
              statusColor = Colors.orange.shade600;
              dueDateMessage = 'Due in ${daysUntilDue} days!';
            } else {
              statusColor = colorScheme.secondary;
              dueDateMessage = '${daysUntilDue} days remaining';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                clipBehavior: Clip.antiAlias, // For rounding corners
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: statusColor.withOpacity(0.2),
                      width: 1.5), // Light border based on status
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.onSurface.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // --- Bill Details Row ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.payment_rounded,
                              color: statusColor, size: 30),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Frequency: $frequency | Due Day: $dayOfMonth',
                                  style: TextStyle(
                                      color:
                                      colorScheme.onSurface.withOpacity(0.7),
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Next Due: $nextDueDateText ($dueDateMessage)',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // --- Amount Display ---
                          Text(
                            '₹${NumberFormat('#,##0').format(amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Action and Last Paid Row ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(
                            0.1), // Light color strip
                        border: Border(
                            top: BorderSide(
                                color: colorScheme.onSurface.withOpacity(0.1))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Last Paid Info
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.history_toggle_off_rounded,
                                    size: 18,
                                    color:
                                    colorScheme.onSurface.withOpacity(0.6)),
                                const SizedBox(width: 5),
                                Text(
                                  'Last Paid: $lastPaidText',
                                  style: TextStyle(
                                      color:
                                      colorScheme.onSurface.withOpacity(0.6),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          // Action Buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Mark as Paid Button
                              Tooltip(
                                message: 'Mark as Paid',
                                child: IconButton(
                                  icon: Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Colors.green.shade600,
                                      size: 24),
                                  onPressed: () => _markAsPaid(
                                    billDoc.id,
                                    name,
                                    amount,
                                    frequency,
                                    dayOfMonth,
                                  ),
                                ),
                              ),
                              // Delete Button
                              Tooltip(
                                message: 'Delete Bill',
                                child: IconButton(
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: Colors.red.shade400, size: 24),
                                  onPressed: () => showDialog(
                                    // Dialog for confirmation
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Bill'),
                                      content: Text(
                                          'Are you sure you want to delete "${name}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _deleteBill(billDoc.id);
                                          },
                                          child: Text('Delete',
                                              style: TextStyle(
                                                  color: Colors.red.shade600)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}