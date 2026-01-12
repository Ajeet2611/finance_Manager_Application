import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GoalSettingScreen extends StatefulWidget {
  const GoalSettingScreen({super.key});

  @override
  State<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends State<GoalSettingScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _targetAmountController = TextEditingController();
  final TextEditingController _currentSavedController =
  TextEditingController(text: '0');

  DateTime _selectedTargetDate = DateTime.now().add(const Duration(days: 365));
  String _goalType = 'Long-term'; // Unused in this UI but kept for data structure

  static const String _goalCollectionName = 'saving_goals';

  // Use a global key to manage Scaffold state for SnackBar
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  @override
  void dispose() {
    _goalNameController.dispose();
    _targetAmountController.dispose();
    _currentSavedController.dispose();
    super.dispose();
  }

  // ---------- MONTHLY CONTRIBUTION CALCULATION ----------
  double calculateMonthlyContribution({
    required double target,
    required double saved,
    required DateTime targetDate,
  }) {
    final remainingAmount = target - saved;
    if (remainingAmount <= 0) return 0;

    final now = DateTime.now();
    final difference = targetDate.difference(now);

    if (difference.inDays <= 0) return 0;

    // Estimate months remaining (approx 30.44 days per month)
    final monthsRemaining = difference.inDays / 30.44;
    return remainingAmount / monthsRemaining;
  }

  // ---------- DATE PICKER ----------
  Future<void> _selectTargetDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTargetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null && picked != _selectedTargetDate) {
      setState(() {
        _selectedTargetDate = picked;
      });
    }
  }

  // ---------- MONTHLY ESTIMATE TEXT (English) ----------
  String get _monthlyContributionEstimate {
    final target = double.tryParse(_targetAmountController.text) ?? 0;
    final saved = double.tryParse(_currentSavedController.text) ?? 0;

    final value = calculateMonthlyContribution(
      target: target,
      saved: saved,
      targetDate: _selectedTargetDate,
    );

    if (value <= 0) {
      return target <= saved
          ? "Goal Achieved!"
          : "Invalid / Past Date";
    }

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return '${currencyFormatter.format(value)} / Month';
  }

  // ---------- SAVE GOAL (English Messages) ----------
  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Please Log In to save the goal.');
      return;
    }

    final targetAmount = double.tryParse(_targetAmountController.text) ?? 0;
    final currentSaved = double.tryParse(_currentSavedController.text) ?? 0;

    if (targetAmount <= 0) {
      _showSnackBar('Target amount must be greater than ₹0.', isError: true);
      return;
    }

    if (targetAmount < currentSaved) {
      _showSnackBar('Target amount cannot be less than current savings.', isError: true);
      return;
    }

    final monthlyContribution = calculateMonthlyContribution(
      target: targetAmount,
      saved: currentSaved,
      targetDate: _selectedTargetDate,
    );

    try {
      await _firestore
          .collection("users")
          .doc(user.uid)
          .collection(_goalCollectionName)
          .add({
        'name': _goalNameController.text.trim(),
        'targetAmount': targetAmount,
        'achievedAmount': currentSaved,
        'targetDate': Timestamp.fromDate(_selectedTargetDate),
        'goalType': _goalType,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'monthlyContribution': monthlyContribution,
      });

      _showSnackBar('Goal successfully added!', isError: false);
      _resetForm();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  // ---------- STREAM ACTIVE GOALS ----------
  Stream<QuerySnapshot> _getGoalsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection("users")
        .doc(user.uid)
        .collection(_goalCollectionName)
        .snapshots();
  }

  // ---------- MARK AS COMPLETED / RESTORE (English Messages) ----------
  Future<void> _markAsComplete(String id, bool isCompleted) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore
        .collection("users")
        .doc(user.uid)
        .collection(_goalCollectionName)
        .doc(id);

    double newMonthly = 0;

    if (!isCompleted) {
      final doc = await ref.get();
      if(doc.exists) {
        final data = doc.data()!;
        final targetDateTimestamp = data['targetDate'] as Timestamp?;
        final targetDate = targetDateTimestamp?.toDate() ?? DateTime.now().add(const Duration(days: 365));

        newMonthly = calculateMonthlyContribution(
          target: (data['targetAmount'] ?? 0).toDouble(),
          saved: (data['achievedAmount'] ?? 0).toDouble(),
          targetDate: targetDate,
        );
      }
    }

    await ref.update({
      'isCompleted': isCompleted,
      'completionDate': isCompleted ? FieldValue.serverTimestamp() : null,
      'monthlyContribution': newMonthly,
    });

    _showSnackBar(
        isCompleted ? 'Goal Completed!' : 'Goal Restored!',
        isError: false);
  }

  // ---------- DELETE GOAL (English Message) ----------
  Future<void> _deleteGoal(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection("users")
        .doc(user.uid)
        .collection(_goalCollectionName)
        .doc(id)
        .delete();

    _showSnackBar('Goal Deleted.', isError: false);
  }

  // ---------- UPDATE GOAL AMOUNT (English Messages) ----------
  Future<void> _updateGoalAmount(
      String id,
      String name,
      double achieved,
      double targetAmount,
      DateTime targetDate,
      ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Funds: $name"),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Amount (₹)",
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  _showSnackBar('Please enter a valid amount.', isError: true);
                  Navigator.pop(context);
                  return;
                }

                final newAchieved = achieved + amount;
                // Check for completion, allowing for minor floating point issues by checking if newAchieved is >= targetAmount
                final completed = newAchieved >= targetAmount * 0.999;

                await _firestore
                    .collection("users")
                    .doc(user.uid)
                    .collection(_goalCollectionName)
                    .doc(id)
                    .update({
                  // Clamp to ensure achievedAmount doesn't significantly exceed targetAmount in data
                  'achievedAmount': newAchieved.clamp(0, targetAmount),
                  'isCompleted': completed,
                  'completionDate':
                  completed ? FieldValue.serverTimestamp() : null,
                  'monthlyContribution': completed
                      ? 0
                      : calculateMonthlyContribution(
                    target: targetAmount,
                    saved: newAchieved.clamp(0, targetAmount).toDouble(),
                    targetDate: targetDate,
                  ),
                });

                Navigator.pop(context);
                final addedAmountFormatted = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount);
                _showSnackBar('$addedAmountFormatted added.', isError: false);
              },
              child: const Text("Add"),
            )
          ],
        );
      },
    );
  }

  // ---------- RESET FORM ----------
  void _resetForm() {
    _goalNameController.clear();
    _targetAmountController.clear();
    _currentSavedController.text = '0';
    _selectedTargetDate = DateTime.now().add(const Duration(days: 365));
    setState(() {});
  }

  // ---------- SNACKBAR (Theme-aware) ----------
  void _showSnackBar(String msg, {bool isError = true}) {
    // Ensure context is available and mounted
    if (!mounted) return;

    final ColorScheme cs = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? cs.error : cs.tertiary, // Use error/tertiary for better theme integration
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ---------- UI BUILD METHODS ----------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Set Savings Goal"),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildFormUI(),
            const Divider(height: 40),
            _buildGoalList(),
          ],
        ),
      ),
    );
  }

  // ---------- FORM UI (English) ----------
  Widget _buildFormUI() {
    final cs = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _goalNameController,
            decoration: const InputDecoration(
                labelText: "Goal Name",
                prefixIcon: Icon(Icons.star_border),
                border: OutlineInputBorder()
            ),
            validator: (v) =>
            v == null || v.trim().isEmpty ? "Please enter a name" : null,
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _targetAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
                labelText: "Target Amount (₹)",
                prefixIcon: Icon(Icons.trending_up),
                border: OutlineInputBorder()
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) =>
            v == null || double.tryParse(v) == null || double.parse(v) <= 0 ? "Please enter a valid amount (> ₹0)" : null,
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _currentSavedController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
                labelText: "Current Saved Amount (₹)",
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder()
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 15),

          // --- Target Date ---
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.onSurface.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                  "Target Date: ${DateFormat('dd MMM yyyy').format(_selectedTargetDate)}"),
              leading: Icon(Icons.calendar_month, color: cs.primary),
              trailing: Icon(Icons.edit, color: cs.secondary),
              onTap: () => _selectTargetDate(context),
            ),
          ),

          const SizedBox(height: 20),

          // --- Monthly Estimate ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Estimated Monthly Contribution:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(
                  _monthlyContributionEstimate,
                  style: TextStyle(
                      fontSize: 24,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveGoal,
              icon: const Icon(Icons.add_task),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text("Save Goal", style: TextStyle(fontSize: 16)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- GOAL LIST (English) ----------
  Widget _buildGoalList() {
    final cs = Theme.of(context).colorScheme;
    final user = _auth.currentUser;

    if (user == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 40.0),
        child: Center(child: Text("Please log in to view data.")),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getGoalsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (snap.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Error fetching data: ${snap.error.toString()}",
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
          ));
        }

        final allDocs = snap.data?.docs ?? [];

        if (allDocs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: Text("No Goals Set Yet", style: TextStyle(fontStyle: FontStyle.italic))),
          );
        }

        // --- LOCAL SORTING: Incomplete first, then by earliest target date ---
        final sortedDocs = allDocs.toList();
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aCompleted = aData['isCompleted'] ?? false;
          final bCompleted = bData['isCompleted'] ?? false;

          // 1. Incomplete (false) comes before Complete (true)
          if (aCompleted != bCompleted) {
            return aCompleted ? 1 : -1;
          }

          // 2. If status is the same, sort by targetDate (Ascending/Earliest first)
          try {
            final aDateTimestamp = aData['targetDate'] as Timestamp?;
            final bDateTimestamp = bData['targetDate'] as Timestamp?;

            final aDate = aDateTimestamp?.toDate() ?? DateTime.now();
            final bDate = bDateTimestamp?.toDate() ?? DateTime.now();

            return aDate.compareTo(bDate);
          } catch (e) {
            return 0; // Maintain order if date conversion fails
          }
        });
        // --- END LOCAL SORTING ---

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Savings Goals:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDocs.length,
              itemBuilder: (context, i) {
                final d = sortedDocs[i];
                final data = d.data() as Map<String, dynamic>;
                final id = d.id;

                final name = data['name'];
                final target = (data['targetAmount'] ?? 0).toDouble();
                final saved = (data['achievedAmount'] ?? 0).toDouble();
                final isCompleted = data['isCompleted'] ?? false;

                final targetDateTimestamp = data['targetDate'] as Timestamp?;
                final targetDate = targetDateTimestamp?.toDate() ?? DateTime.now();

                final monthlyContribution = (data['monthlyContribution'] ?? 0.0).toDouble();

                final progress = (saved / target).clamp(0.0, 1.0);

                final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: isCompleted ? 1 : 4,
                  // Use theme colors for visual grouping/status
                  color: isCompleted ? cs.surfaceVariant : cs.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted ? cs.onSurface.withOpacity(0.6) : cs.onSurface,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Saved: ${currencyFormatter.format(saved)} / ${currencyFormatter.format(target)}",
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant
                                    ),
                                  ),
                                  Text(
                                    "Target Date: ${DateFormat('dd MMM yyyy').format(targetDate)}",
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant
                                    ),
                                  ),
                                  if (!isCompleted && monthlyContribution > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        "Monthly Estimate: ${currencyFormatter.format(monthlyContribution)}",
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                // --- Add Amount Button ---
                                if (!isCompleted)
                                  IconButton(
                                    icon: Icon(Icons.add_circle, color: cs.secondary),
                                    tooltip: "Add Funds",
                                    onPressed: () => _updateGoalAmount(
                                      id,
                                      name,
                                      saved,
                                      target,
                                      targetDate,
                                    ),
                                  ),
                                // --- Complete/Undo Button ---
                                IconButton(
                                  icon: Icon(
                                    isCompleted ? Icons.undo : Icons.check_circle_outline,
                                    color: isCompleted ? cs.tertiary : Colors.green.shade700,
                                  ),
                                  tooltip: isCompleted ? "Restore Goal" : "Mark Complete",
                                  onPressed: () =>
                                      _markAsComplete(id, !isCompleted),
                                ),
                                // --- Delete Button ---
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: cs.error,
                                  ),
                                  tooltip: "Delete Goal",
                                  onPressed: () => _deleteGoal(id),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // --- Progress Bar ---
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: cs.onSurface.withOpacity(0.1),
                          color: isCompleted ? Colors.green.shade700 : cs.primary,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "${(progress * 100).toStringAsFixed(0)}% Complete",
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}