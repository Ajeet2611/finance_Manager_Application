import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CategoryTransactionsScreen extends StatefulWidget {
  final String categoryName;
  final int month;
  final int year;

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryName,
    required this.month,
    required this.year,
  });

  @override
  State<CategoryTransactionsScreen> createState() => _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState extends State<CategoryTransactionsScreen> {
  // 💡 Filter options are now explicitly English strings
  String _selectedFilter = 'All';

  // Helper function to map category names to relevant icons
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Needs': return Icons.local_mall_outlined;
      case 'Wants': return Icons.shopping_bag_outlined;
      case 'Savings': return Icons.savings_outlined;
      case 'Salary': return Icons.payments_outlined;
      case 'Bonus': return Icons.star_border;
      default: return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.categoryName} Transactions')),
        body: const Center(child: Text('User not authenticated.')),
      );
    }

    // 💡 Theme-aware colors
    final primaryTextColor = Theme.of(context).textTheme.titleLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.categoryName} Transactions',
          style: TextStyle(color: primaryTextColor),
        ),
        foregroundColor: primaryTextColor,
        backgroundColor: colorScheme.surface,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Filter Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                    'Filter Transactions:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor
                    )
                ),
                const SizedBox(width: 10),
                Theme(
                  // Override theme for the dropdown to ensure text color is readable
                  data: Theme.of(context).copyWith(
                    canvasColor: colorScheme.surface,
                  ),
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    iconEnabledColor: primaryTextColor,
                    items: const ['All', 'Today', 'Last 7 Days', 'Last 30 Days']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                            value,
                            style: TextStyle(color: primaryTextColor)
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedFilter = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Transaction History List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredTransactionsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Failed to load transactions: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              _getCategoryIcon(widget.categoryName),
                              size: 50,
                              color: colorScheme.secondary
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No transactions found for ${widget.categoryName} in this period.',
                            style: TextStyle(color: secondaryTextColor),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          if (widget.categoryName == 'Savings')
                            Text(
                              'Tip: Ensure you have added your savings amount as a transaction with category "Savings" for the selected month.',
                              style: TextStyle(color: secondaryTextColor?.withOpacity(0.7), fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  );
                }

                final transactions = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index].data() as Map<String, dynamic>;
                    final amount = (transaction['amount'] ?? 0.0).toDouble();
                    final timestamp = transaction['timestamp'] as Timestamp?;
                    final item = transaction['item'] ?? 'Transaction';

                    final date = timestamp != null
                        ? (timestamp.toDate().day == DateTime.now().day &&
                        timestamp.toDate().month == DateTime.now().month &&
                        timestamp.toDate().year == DateTime.now().year
                        ? 'Today' // Display 'Today' for same-day transactions
                        : DateFormat('MMM d, h:mm a').format(timestamp.toDate()))
                        : 'N/A';

                    final isIncome = widget.categoryName == 'Salary' || widget.categoryName == 'Bonus';
                    // Savings is treated as an 'expense' towards a goal in 50/30/20, but positive flow
                    final isSavings = widget.categoryName == 'Savings';

                    // Theme-neutral colors for amount status
                    final amountColor = isIncome
                        ? Colors.green.shade600 // Income/Bonus
                        : isSavings
                        ? colorScheme.primary // Savings (Positive Goal Flow)
                        : colorScheme.error; // Needs/Wants (Expense)

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: amountColor.withOpacity(0.15),
                          child: Icon(_getCategoryIcon(widget.categoryName), color: amountColor, size: 22),
                        ),
                        title: Text(item, style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
                        subtitle: Text(date, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                        trailing: Text(
                          // Income and Savings are shown as positive (+)
                          '${isIncome || isSavings ? '+' : '-'} ₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: amountColor),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredTransactionsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    // --- Base Query: Specific User -> Specific Month -> Transactions -> Specific Category ---
    final docId = '${widget.year}-${widget.month.toString().padLeft(2, '0')}';
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('monthly_records')
        .doc(docId)
        .collection('transactions')
        .where('category', isEqualTo: widget.categoryName);

    // --- Date Range Calculation (Needed for 'All' to define boundaries) ---
    final selectedStartOfMonth = DateTime(widget.year, widget.month, 1);
    final selectedEndOfMonth = DateTime(
      widget.month == 12 ? widget.year + 1 : widget.year,
      widget.month == 12 ? 1 : widget.month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1));


    // --- Apply Time Filters ---
    DateTime now = DateTime.now();
    DateTime filterStart;

    switch (_selectedFilter) {
      case 'Today':
        filterStart = DateTime(now.year, now.month, now.day);
        // Apply filter only if 'Today' is within the selected month
        if (filterStart.isBefore(selectedStartOfMonth) || filterStart.isAfter(selectedEndOfMonth)) {
          // If filter date is outside the monthly scope, return only transactions from the start of the month to the end of the month
          query = query
              .where('timestamp', isGreaterThanOrEqualTo: selectedStartOfMonth)
              .where('timestamp', isLessThanOrEqualTo: selectedEndOfMonth);
        } else {
          // Apply 'Today' filter
          query = query.where('timestamp', isGreaterThanOrEqualTo: filterStart)
              .where('timestamp', isLessThanOrEqualTo: now);
        }
        break;

      case 'Last 7 Days':
        filterStart = now.subtract(const Duration(days: 7));
        // Clamp filter start to the beginning of the selected month
        if (filterStart.isBefore(selectedStartOfMonth)) {
          filterStart = selectedStartOfMonth;
        }
        query = query.where('timestamp', isGreaterThanOrEqualTo: filterStart)
            .where('timestamp', isLessThanOrEqualTo: now);
        break;

      case 'Last 30 Days':
        filterStart = now.subtract(const Duration(days: 30));
        // Clamp filter start to the beginning of the selected month
        if (filterStart.isBefore(selectedStartOfMonth)) {
          filterStart = selectedStartOfMonth;
        }
        query = query.where('timestamp', isGreaterThanOrEqualTo: filterStart)
            .where('timestamp', isLessThanOrEqualTo: now);
        break;

      case 'All':
      default:
      // For 'All', implicitly filtered by the path, but good practice to constrain by date range for robustness across Firestore versions.
        query = query
            .where('timestamp', isGreaterThanOrEqualTo: selectedStartOfMonth)
            .where('timestamp', isLessThanOrEqualTo: selectedEndOfMonth);
        break;
    }

    // IMPORTANT: Ordering is crucial for performance and displaying newest first
    return query.orderBy('timestamp', descending: true).snapshots();
  }
}