import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Import necessary screens
import 'category_transactions_screen.dart';

class HomeBody extends StatefulWidget {
  final int selectedMonth;
  final int selectedYear;
  final Function(int) onMonthChanged;
  final Function(int) onYearChanged;
  final DateTime? userCreationDate;
  final Stream<DocumentSnapshot>? monthlyDataStream;
  final Stream<QuerySnapshot>? transactionsStream;

  // 💡 Update 1: Replaced showSalaryDialog with two new functions
  final VoidCallback setBaseSalary;
  final VoidCallback addExtraIncome;

  final Function(String, double, String) deleteTransaction;
  final IconData Function(String) getCategoryIcon;
  final String Function(int) getMonthName;

  const HomeBody({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.userCreationDate,
    required this.monthlyDataStream,
    required this.transactionsStream,

    // 💡 Update 1: Added new functions to the constructor
    required this.setBaseSalary,
    required this.addExtraIncome,

    required this.deleteTransaction,
    required this.getCategoryIcon,
    required this.getMonthName,
  });

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true; // Essential for preventing state loss and reload

  // --- 💡 Helper Widgets ---

  Widget _buildProgressItem(BuildContext context, String title, double spent, double limit, Color color) {
    double progress = limit > 0 ? spent / limit : 0.0;
    progress = progress > 1 ? 1.0 : progress;

    final spentText = '₹ ${spent.toStringAsFixed(0)} / ₹ ${limit.toStringAsFixed(0)}';

    // 💡 Fix: Theme-aware text color
    final primaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CategoryTransactionsScreen(
              categoryName: title.split(' ').first,
              month: widget.selectedMonth, // Use widget.
              year: widget.selectedYear, // Use widget.
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                // ✅ Update: Use Theme color
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primaryTextColor),
              ),
              Text(
                spentText,
                // ✅ Update: Use Theme color
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              // ✅ Update: Use Theme surface color for background
              backgroundColor: Theme.of(context).colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearPicker(List<int> yearsList, List<int> monthsList) {
    // 💡 Fix: Theme-aware text color
    final primaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color;

    return Row(
      children: [
        // Month Picker
        DropdownButton<int>(
          value: widget.selectedMonth, // Use widget.
          icon: Icon(Icons.arrow_drop_down, color: primaryTextColor), // ✅ Update: Use Theme color
          underline: Container(height: 0),
          onChanged: (int? newValue) {
            if (newValue != null) {
              widget.onMonthChanged(newValue); // Use widget.
            }
          },
          items: monthsList.map<DropdownMenuItem<int>>((int month) {
            return DropdownMenuItem<int>(
              value: month,
              child: Text(
                widget.getMonthName(month), // Use widget.
                // ✅ Update: Use Theme color
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor),
              ),
            );
          }).toList(),
        ),
        const SizedBox(width: 8),
        // Year Picker
        DropdownButton<int>(
          value: widget.selectedYear, // Use widget.
          icon: Icon(Icons.arrow_drop_down, color: secondaryTextColor), // ✅ Update: Use Theme color
          underline: Container(height: 0),
          onChanged: (int? newValue) {
            if (newValue != null) {
              widget.onYearChanged(newValue); // Use widget.
            }
          },
          items: yearsList.map<DropdownMenuItem<int>>((int year) {
            return DropdownMenuItem<int>(
              value: year,
              child: Text(
                year.toString(),
                // ✅ Update: Use Theme color
                style: TextStyle(color: secondaryTextColor, fontSize: 16),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- 💡 New Widget: Salary Prompt ---
  Widget _buildSalaryPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA500).withOpacity(0.9), // Orange Background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFFA500).withOpacity(0.4), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 10),
          // 💡 TRANSLATION: Maasik Budget Missing!
          const Text(
            'Monthly Budget Missing!',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24, color: Colors.white),
          ),
          const SizedBox(height: 8),
          // 💡 TRANSLATION: Kripya is mahine ka kul vetan...
          const Text(
            'Please set the total salary for this month so we can calculate the 50/30/20 budget breakdown.',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // 💡 Update 2: Now call setBaseSalary
              onPressed: widget.setBaseSalary,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                // 💡 TRANSLATION: Abhi Base Salary Set Karein
                'Set Base Salary Now',
                style: TextStyle(color: Color(0xFFFFA500), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ----------------------------------------------------


  // --- 🏗️ Main Build Method ---

  @override
  Widget build(BuildContext context) {
    super.build(context); // Call super.build(context) for AutomaticKeepAliveClientMixin to work

    // 💡 Fix: Theme-aware text color for main sections
    final primaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color;
    final dividerColor = Theme.of(context).dividerColor;


    final creationYear = widget.userCreationDate?.year ?? DateTime.now().year; // Use widget.
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;

    final yearsList = List.generate(
      currentYear - creationYear + 1,
          (index) => creationYear + index,
    ).reversed.toList();

    List<int> monthsList;
    if (widget.selectedYear == currentYear) { // Use widget.
      monthsList = List.generate(currentMonth, (index) => index + 1).reversed.toList();
    } else {
      monthsList = List.generate(12, (index) => index + 1);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: widget.monthlyDataStream, // Use widget.
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 💡 TRANSLATION: डेटा लोड करने में विफल रहा:
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load data: ${snapshot.error}'));
        }

        // Logic for data extraction and calculation remains unchanged
        final data = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : {};

        final totalSalary = (data['totalSalary'] ?? 0.0).toDouble();
        final needsSpent = (data['NeedsSpent'] ?? 0.0).toDouble();
        final wantsSpent = (data['WantsSpent'] ?? 0.0).toDouble();
        final savingsSpent = (data['SavingSpent'] ?? 0.0).toDouble();
        final totalSpent = needsSpent + wantsSpent + savingsSpent;
        final totalBalance = totalSalary - totalSpent;

        final needsLimit = totalSalary * 0.5;
        final wantsLimit = totalSalary * 0.3;
        final savingsLimit = totalSalary * 0.2;

        // 💡 New Logic: Show prompt card if salary is 0
        final isSalaryMissing = totalSalary == 0.0;

        // 💡 Show "Add Bonus" button only if salary is set
        final showAddBonusButton = !isSalaryMissing;


        return SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 📅 Month/Year Picker and Bonus Button ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMonthYearPicker(yearsList, monthsList),
                  // Add Bonus Button (Conditional)
                  if (showAddBonusButton)
                    GestureDetector(
                      // 💡 Update 3: Call addExtraIncome and update text
                      onTap: widget.addExtraIncome,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18, color: Colors.amber[800]),
                            const SizedBox(width: 4),
                            // 💡 TRANSLATION: बोनस जोड़ें
                            Text('Add', style: TextStyle(color: Colors.amber[800], fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // --- 💰 Budget Card / Salary Prompt Card (Conditional) ---
              if (isSalaryMissing)
                _buildSalaryPromptCard() // ⬅️ Show this card if salary is missing
              else
              // (Colors are white, so this section is fine)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF87CEEB), Color(0xFF4682B4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF4682B4).withOpacity(0.4), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Budget (Salary)
                      // 💡 TRANSLATION: इस महीने का कुल बजट:
                      const Text('Total Budget for this Month:', style: TextStyle(fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        '₹ ${totalSalary.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 32, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      // Total Spent and Remaining Balance (The added section)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Total Spent (Total Expanses)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 💡 TRANSLATION: कुल खर्च
                              const Text('Total Expense', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Text(
                                '₹ ${totalSpent.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFF6B6B)),
                              ),
                            ],
                          ),
                          // Total Remaining Balance
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 💡 TRANSLATION: शेष बैलेंस
                              const Text('Remaining Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Text(
                                '₹ ${totalBalance.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF32CD32)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // --- 📊 Progress Section (50/30/20 Rule) ---
              // ✅ Update: Use Theme color
              // 💡 TRANSLATION: 50/30/20 नियम
              Text('50/30/20 Rule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryTextColor)),
              const SizedBox(height: 16),

              // If salary is 0, no point in showing progress bars
              if (isSalaryMissing)
                Center(child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  // 💡 TRANSLATION: कृपया सैलरी सेट करें ताकि 50/30/20 का ब्रेकडाउन दिख सके।
                  child: Text('Please set the salary to view the 50/30/20 breakdown.', style: TextStyle(color: secondaryTextColor)),
                ))
              else ...[
                // 💡 TRANSLATION: आवश्यकताएं (Needs)
                _buildProgressItem(context, 'Needs (50%)', needsSpent, needsLimit, const Color(0xFFFFD700)),
                const SizedBox(height: 16),
                // 💡 TRANSLATION: इच्छाएं (Wants)
                _buildProgressItem(context, 'Wants (30%)', wantsSpent, wantsLimit, const Color(0xFF4682B4)),
                const SizedBox(height: 16),
                // 💡 TRANSLATION: बचत (Saving)
                _buildProgressItem(context, 'Savings (20%)', savingsSpent, savingsLimit, const Color(0xFF32CD32)),
              ],
              const SizedBox(height: 32),

              // --- 📜 Recent Transactions / हाल के खर्च ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🚀 FIX: 'हाल के खर्च' replaced with 'Recent Transactions'
                  // 💡 TRANSLATION: हाल के लेन-देन
                  Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryTextColor)),
                  TextButton(
                    onPressed: () {
                      // TODO: Navigate to All Transactions screen
                    },
                    // 💡 TRANSLATION: सभी देखें
                    child: const Text('View All', style: TextStyle(color: Color(0xFF4682B4), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot>(
                stream: widget.transactionsStream, // Use widget.
                builder: (context, transactionSnapshot) {
                  // ... (Error and loading states)
                  if (transactionSnapshot.connectionState == ConnectionState.waiting) {
                    // ✅ Update: Use Theme color
                    // 💡 TRANSLATION: लोड हो रहा है...
                    return Center(child: Text('Loading...', style: TextStyle(color: secondaryTextColor)));
                  }
                  if (transactionSnapshot.hasError) {
                    // ✅ Update: Use Theme color
                    // 💡 TRANSLATION: लेन-देन लोड करने में विफल रहा।
                    return Center(child: Text('Failed to load transactions.', style: TextStyle(color: secondaryTextColor)));
                  }
                  if (!transactionSnapshot.hasData || transactionSnapshot.data!.docs.isEmpty) {
                    // ✅ Update: Use Theme color
                    return Center(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      // 💡 TRANSLATION: इस महीने कोई लेन-देन नहीं।
                      child: Text('No transactions this month.', style: TextStyle(color: secondaryTextColor)),
                    ));
                  }

                  final transactions = transactionSnapshot.data!.docs;
                  final displayCount = transactions.length > 5 ? 5 : transactions.length;

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayCount,
                    // ✅ Update: Use Theme color for divider
                    separatorBuilder: (context, index) => Divider(height: 1, color: dividerColor.withOpacity(0.5)),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final data = transaction.data() as Map<String, dynamic>;
                      final amount = (data['amount'] ?? 0.0).toDouble();
                      final category = data['category'] ?? 'N/A';
                      final item = data['item'] ?? 'No Item'; // 💡 TRANSLATION: कोई वस्तु नहीं
                      final timestamp = data['timestamp'] as Timestamp?;
                      // 💡 Fix: Treat 'Bonus' as Income too
                      final isIncome = category == 'Salary' || category == 'Bonus';

                      final formattedDate = timestamp != null ? DateFormat('MMM d, h:mm a').format(timestamp.toDate()) : 'N/A';

                      // 🚀 FIX: Explicitly green color for Income (Salary/Bonus) item and amount
                      final itemColor = isIncome ? Colors.green : (category == 'Needs' || category == 'Wants' ? const Color(0xFFFF8C00) : const Color(0xFF4682B4));
                      final iconData = widget.getCategoryIcon(category); // Use widget.
                      final amountColor = isIncome ? const Color(0xFF32CD32) : const Color(0xFFFF6B6B);

                      return Dismissible(
                        key: Key(transaction.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return widget.deleteTransaction(transaction.id, amount, category); // Use widget.
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: itemColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                child: Icon(iconData, color: itemColor, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ✅ Update: Use Theme color
                                    Text(item, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: primaryTextColor)),
                                    // ✅ Update: Use Theme color
                                    Text(formattedDate, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIncome ? '+' : '-'} ₹ ${amount.toStringAsFixed(0)}',
                                style: TextStyle(color: amountColor, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}