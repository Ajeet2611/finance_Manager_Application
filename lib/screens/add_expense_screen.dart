import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends StatefulWidget {
  final double totalSalary;
  final double needsSpent;
  final double wantsSpent;
  final double savingsSpent;

  const AddExpenseScreen({
    super.key,
    required this.totalSalary,
    required this.needsSpent,
    required this.wantsSpent,
    required this.savingsSpent,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? currentUser;

  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _detectedCategory = '';

  String? _selectedSubCategory;

  // 💡 TRANSLATION: Sub-categories are now English
  final Map<String, List<String>> _subCategories = {
    'Needs': ['Rent/EMI', 'Groceries/Food', 'Utilities (Elec/Water/Gas)', 'Transport/Fuel', 'Health/Medical', 'Education', 'Other Needs'],
    'Wants': ['Entertainment/Streaming', 'Dining Out/Cafes', 'Shopping/Clothes', 'Travel/Vacation', 'Electronics/Gadgets', 'Personal Care/Salon', 'Other Wants'],
    'Saving': ['Emergency Fund', 'Investment (SIP/MF)', 'Retirement Fund', 'Specific Goal Contribution', 'Other Saving'],
  };

  // 💡 TRANSLATION: Keywords are now primarily English
  final Map<String, List<String>> _categoryKeywords = {
    'Needs': [
      // Food & Groceries
      'milk','vegetable','grocery','ration','food','flour','rice','oil','spices','bread',
      'butter','cheese','eggs','meat','chicken','fish','household','daily needs','fruits',
      'subzi','sabji','kirana','aata','chawal','tel',

      // Utilities
      'electricity','power','current bill','light bill','water','gas','lpg','fuel','diesel',
      'petrol','wifi','internet','broadband','tv','dth','mobile recharge','phone recharge',

      // Housing
      'rent','house rent','pg rent','hostel rent','maintenance','repair','plumber',
      'electrician','construction','painting','home repairs','service charge','kiyaara',

      // Education
      'school','fees','college','university','coaching','tuition','books','stationery',
      'uniform','bus fee','van fee',

      // Transport
      'car','bike','service','servicing','tyre','brake','oil change','transport','bus',
      'auto','cab','taxi','train ticket','metro','parking',

      // Health
      'medicine','medical','meds','chemist','doctor','checkup','hospital','clinic','health',
      'test','blood test','treatment',

      // Mandatory Payments
      'loan','emi','insurance','premium','policy','tax','lic','pf','pension',
      'credit card bill','bank charges'
    ],
    'Wants': [
      // Entertainment
      'party','fun','movie','cinema','theatre','netflix','amazon','ott','gaming','game','entertainment',

      // Eating Out
      'eating out','restaurant','cafe','coffee','tea stall','chai','pizza','burger',
      'snacks','fast food','hotel','bbq','buffet',

      // Shopping
      'shopping','fashion','clothes','jeans','tshirt','shoes','footwear','makeup',
      'cosmetics','beauty','perfume','watch','accessories','bags','jewelry','gift',

      // Electronics
      'electronics','mobile','phone','laptop','headphones','earbuds','smartwatch','camera',
      'charger','gadget','tech',

      // Travel / Leisure
      'travel','trip','outing','tour','vacation','holiday','hotel booking','flight','road trip',

      // Personal & Lifestyle
      'salon','spa','massage','grooming','haircut','beauty parlour','gym','fitness','sports',

      // Hobbies
      'music','dance','instrument','art','craft','creative items'
    ],
    'Saving': [
      // Basic Savings
      'saving','deposit','bank deposit','savings account','income','salary','bonus','commission',

      // Investments
      'mutual fund','mf','sip','share','stock','equity','demat','fd','fixed deposit',
      'rd','recurring deposit','p2p lending','crypto','bitcoin','bond','wealth','portfolio',

      // Assets
      'gold','silver','property','plot','land','real estate','assets',

      // Retirement / Long-term
      'pf','provident fund','pension','nps','retirement fund','life insurance','lic',
      'term plan','health insurance','premium','policy'
    ],
  };

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
  }

  void _detectCategory(String item) {
    String foundCategory = '';
    final normalizedItem = item.toLowerCase();

    for (var entry in _categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (var keyword in keywords) {
        if (normalizedItem.contains(keyword)) {
          foundCategory = category;
          break;
        }
      }
      if (foundCategory.isNotEmpty) {
        break;
      }
    }
    setState(() {
      _detectedCategory = foundCategory;
      _selectedSubCategory = null;
    });
  }

  // 💡 TRANSLATION: Main function with English messages
  Future<void> _addExpense() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to add an expense.')));
      return;
    }

    if (_itemController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields.')));
      return;
    }

    final double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.')));
      return;
    }

    if (_detectedCategory.isEmpty) {
      // If category is not detected, show dialog for manual selection
      await _showCategorySelectionDialog(amount);

      // Check if the user selected a category after the dialog closed
      if (_detectedCategory.isEmpty) return;
    }

    if (_selectedSubCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Sub-Category.')));
      return;
    }

    _checkAndSaveExpense(amount, _detectedCategory, _selectedSubCategory!);
  }

  // 💡 TRANSLATION: Budget check function with English messages
  Future<void> _checkAndSaveExpense(double amount, String category, String subCategory) async {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    if (widget.totalSalary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your total salary on the Home Screen before adding expenses.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double currentSpent = 0.0;
    double categoryLimit = 0.0;
    String limitPercentage = '';

    switch (category) {
      case 'Needs':
        currentSpent = widget.needsSpent;
        categoryLimit = widget.totalSalary * 0.5; // 50%
        limitPercentage = '50%';
        break;
      case 'Wants':
        currentSpent = widget.wantsSpent;
        categoryLimit = widget.totalSalary * 0.3; // 30%
        limitPercentage = '30%';
        break;
      case 'Saving':
        currentSpent = widget.savingsSpent;
        categoryLimit = widget.totalSalary * 0.2; // 20%
        limitPercentage = '20%';
        break;
    }

    final remainingInCategory = categoryLimit - currentSpent;

    if (amount > remainingInCategory && category != 'Saving') {
      // Show warning for Needs/Wants if exceeding the limit
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This expense will exceed your $category budget ($limitPercentage). Only ${currencyFormatter.format(remainingInCategory)} remaining.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final totalSpentThisMonth = widget.needsSpent + widget.wantsSpent + widget.savingsSpent;
    final remainingTotalBudget = widget.totalSalary - totalSpentThisMonth;

    if (amount > remainingTotalBudget) {
      // Show warning if exceeding the total budget
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WARNING: This expense exceeds your total remaining budget (${currencyFormatter.format(remainingTotalBudget)}).'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    await _saveTransaction(amount, category, subCategory);
  }

  // 💡 TRANSLATION: Save function with English messages
  Future<void> _saveTransaction(double amount, String category, String subCategory) async {
    try {
      final now = DateTime.now();
      final docId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final monthlyDocRef = _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('monthly_records')
          .doc(docId);

      // Update monthly summary
      await monthlyDocRef.set({
        'totalSalary': widget.totalSalary,
        'month': now.month,
        'year': now.year,
        // Use increment based on the category
        'NeedsSpent': category == 'Needs' ? FieldValue.increment(amount) : FieldValue.increment(0),
        'WantsSpent': category == 'Wants' ? FieldValue.increment(amount) : FieldValue.increment(0),
        'SavingSpent': category == 'Saving' ? FieldValue.increment(amount) : FieldValue.increment(0),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));


      // Add transaction to sub-collection
      await monthlyDocRef.collection('transactions').add({
        'item': _itemController.text,
        'amount': amount,
        'category': category,
        'subCategory': subCategory,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense successfully added!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding expense: $e')));
      }
    }
  }

  // 💡 TRANSLATION: Category Selection Dialog
  Future<void> _showCategorySelectionDialog(double amount) async {
    String? tempSelectedCategory = _detectedCategory;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (context, setStateSB) {
              return AlertDialog(
                title: const Text('Select Main Category'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: const Text('Needs (50%)'),
                      value: 'Needs',
                      groupValue: tempSelectedCategory,
                      onChanged: (value) {
                        setStateSB(() { tempSelectedCategory = value; });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Wants (30%)'),
                      value: 'Wants',
                      groupValue: tempSelectedCategory,
                      onChanged: (value) {
                        setStateSB(() { tempSelectedCategory = value; });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Saving (20%)'),
                      value: 'Saving',
                      groupValue: tempSelectedCategory,
                      onChanged: (value) {
                        setStateSB(() { tempSelectedCategory = value; });
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (tempSelectedCategory != null) {
                          // Update main State
                          setState(() {
                            _detectedCategory = tempSelectedCategory!;
                            _selectedSubCategory = null; // Reset sub-category on change
                          });
                          Navigator.pop(dialogContext);
                        } else {
                          // Show a local snackbar/message in the dialog if no category is selected
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category.')));
                        }
                      },
                      child: const Text('Select'),
                    ),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> currentSubCategories = _subCategories[_detectedCategory] ?? [];
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Theme-aware styling
    final primaryColor = colorScheme.primary;
    final surfaceColor = colorScheme.surface;
    final borderColor = colorScheme.onSurface.withOpacity(0.4);
    final containerColor = _detectedCategory.isEmpty
        ? surfaceColor
        : primaryColor.withOpacity(0.15); // Highlight detected category

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Expense'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Item Description ---
            TextFormField(
              controller: _itemController,
              decoration: InputDecoration(
                labelText: 'Item Name / Description',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: surfaceColor,
              ),
              onChanged: _detectCategory,
            ),
            const SizedBox(height: 20),

            // --- Amount ---
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: surfaceColor,
                prefixText: '₹ ',
              ),
            ),

            const SizedBox(height: 20),

            // --- Detected Category Container ---
            GestureDetector(
              onTap: () => _showCategorySelectionDialog(double.tryParse(_amountController.text) ?? 0.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _detectedCategory.isEmpty
                          ? 'Main Category will appear here\n\t Tap to Select'
                          : 'Main Category: $_detectedCategory',
                      style: textTheme.titleMedium!.copyWith(
                        fontWeight: _detectedCategory.isEmpty ? FontWeight.normal : FontWeight.bold,
                        color: _detectedCategory.isEmpty ? textTheme.bodySmall!.color : colorScheme.onSurface,
                      ),
                    ),
                    Icon(Icons.edit, color: colorScheme.secondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- Sub-Category Dropdown ---
            if (_detectedCategory.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Sub-Category (e.g., Groceries)',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: surfaceColor,
                ),
                value: _selectedSubCategory,
                hint: Text('Sub-Category', style: textTheme.bodySmall),
                items: currentSubCategories
                    .map((sub) => DropdownMenuItem(
                  value: sub,
                  child: Text(sub, style: textTheme.bodyMedium),
                ))
                    .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSubCategory = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a Sub-Category';
                  }
                  return null;
                },
                iconEnabledColor: colorScheme.primary,
              ),

            const SizedBox(height: 30),

            // --- Add Expense Button ---
            ElevatedButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Add Expense', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}