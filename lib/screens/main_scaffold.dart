import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart'; // DateFormat के लिए

// Import necessary screens/widgets.
import 'home_body.dart';
import 'analysis_screen.dart';
import 'add_expense_screen.dart';
import 'goal_setting_screen.dart';
import 'profile_screen.dart';


class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 0;
  late int _selectedMonth;
  late int _selectedYear;

  // State Variables
  Stream<DocumentSnapshot>? _monthlyDataStream;
  Stream<QuerySnapshot>? _transactionsStream;

  DateTime? _userCreationDate;
  String? _userName;
  User? _currentUser;
  late StreamSubscription<User?> _authStateSubscription; // Auth state tracking


  // 🚀 New Function: Setting/Overwriting Base Salary (setBaseSalary implementation)
  Future<void> _showBaseSalaryDialog() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final TextEditingController salaryController = TextEditingController();

    // Fetch current base salary for display
    double currentBaseSalary = 0.0;
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        currentBaseSalary = (userDoc.data()?['baseSalary'] ?? 0.0).toDouble();
      }
      salaryController.text = currentBaseSalary > 0 ? currentBaseSalary.toStringAsFixed(0) : '';
    } catch (e) {
      print('Error fetching current base salary: $e');
    }

    final result = await showDialog<double?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Maasik Vetan (Base Salary)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kripya is mahine ($_selectedYear) ka nirdharit vetan (base salary) darj karein. Yeh 50/30/20 budget ka aadhaar banega.'),
              const SizedBox(height: 15),

              TextFormField(
                controller: salaryController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Base Salary Amount',
                  prefixText: '₹ ',
                  border: const OutlineInputBorder(),
                  hintText: currentBaseSalary > 0 ? 'Current: ₹${currentBaseSalary.toStringAsFixed(0)}' : 'e.g., 40000',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Note: Puraani salary overwrite ho jaayegi. Extra income (bonus) wahi rahega.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final amountText = salaryController.text.trim();
                final amount = double.tryParse(amountText);

                if (amount != null && amount >= 0) {
                  Navigator.of(context).pop(amount); // New amount return करें
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kripya sahi (positive/zero) raashi darj karein.')),
                );
              },
              child: const Text('Set Salary'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final newBaseSalary = result;

      try {
        final docId = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final monthlyDocRef = userDocRef.collection('monthly_records').doc(docId);

        // 1. Fetch current extra income
        final monthlyDoc = await monthlyDocRef.get();
        final currentExtraIncome = (monthlyDoc.data()?['extraIncome'] ?? 0.0).toDouble();

        // 2. मासिक रिकॉर्ड अपडेट करें (Overwrite Logic: Base + Extra)
        // Total Salary = New Base Salary + Existing Extra Income
        final newTotalSalary = newBaseSalary + currentExtraIncome;

        await monthlyDocRef.set(
          {
            'baseSalaryAmount': newBaseSalary, // New field to store base amount
            'totalSalary': newTotalSalary, // Total for 50/30/20 breakdown
            // extraIncome remains unchanged
            'lastUpdated': FieldValue.serverTimestamp(),
            'month': _selectedMonth,
            'year': _selectedYear,
          },
          SetOptions(merge: true),
        );

        // 3. User document में भी Base Salary अपडेट करें (Optional but good for tracking)
        await userDocRef.set(
            {'baseSalary': newBaseSalary, 'lastUpdated': FieldValue.serverTimestamp()},
            SetOptions(merge: true)
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Safelata! Base Salary ₹${newBaseSalary.toStringAsFixed(0)} set ki gayi. Total Budget: ₹${newTotalSalary.toStringAsFixed(0)}'
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Base Salary save karne mein truti hui: $e')),
          );
        }
      }
    }
  }

  // 🚀 Refactored Function: Adding Extra Income/Bonus (addExtraIncome implementation)
  Future<void> _showExtraIncomeDialog() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final TextEditingController newIncomeController = TextEditingController();
    double baseSalary = 0.0;
    double totalSalary = 0.0;
    double currentExtraIncome = 0.0;

    try {
      final docId = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      final monthlyDoc = await _firestore.collection('users').doc(user.uid).collection('monthly_records').doc(docId).get();

      if (monthlyDoc.exists) {
        baseSalary = (monthlyDoc.data()?['baseSalaryAmount'] ?? 0.0).toDouble();
        totalSalary = (monthlyDoc.data()?['totalSalary'] ?? 0.0).toDouble();
        currentExtraIncome = (monthlyDoc.data()?['extraIncome'] ?? 0.0).toDouble();
      }
    } catch (e) {
      print('Error fetching income data: $e');
    }

    final result = await showDialog<double?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Extra Income / Bonus'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kripya is mahine ($_selectedYear) ke liye naye income/bonus ki raashi darj karein.'),
              const SizedBox(height: 15),

              // Base Salary (Uneditable) - आधार वेतन सिर्फ जानकारी के लिए
              Text(
                'Base Salary: ₹${baseSalary.toStringAsFixed(0)} | Current Bonus: ₹${currentExtraIncome.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).primaryColor),
              ),
              Text(
                'Total Budget: ₹${totalSalary.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 10),

              // New Income (Editable) - अतिरिक्त आय फ़ील्ड
              TextFormField(
                controller: newIncomeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'New Income Amount to Add',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 5000',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Yeh raashi aapke maasik total income mein jood jayegi.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newAmountText = newIncomeController.text.trim();
                final newAmount = double.tryParse(newAmountText);

                if (newAmount != null && newAmount > 0) {
                  Navigator.of(context).pop(newAmount); // New amount return करें
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kripya sahi (positive) raashi darj karein.')),
                );
              },
              child: const Text('Add Bonus'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final newIncomeAmount = result;

      try {
        final docId = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final monthlyDocRef = userDocRef.collection('monthly_records').doc(docId);

        // 1. मासिक रिकॉर्ड अपडेट करें (Additive Logic)
        await monthlyDocRef.set(
          {
            // दोनों को इंक्रीमेंट करें ताकि होम स्क्रीन पर टोटल सैलरी और प्रोग्रेस बार अपडेट हो जाए
            'totalSalary': FieldValue.increment(newIncomeAmount),
            'extraIncome': FieldValue.increment(newIncomeAmount),
            'lastUpdated': FieldValue.serverTimestamp(),
            'month': _selectedMonth,
            'year': _selectedYear,
          },
          SetOptions(merge: true),
        );

        // 2. एक नया Transaction रिकॉर्ड करें
        await monthlyDocRef.collection('transactions').add({
          'amount': newIncomeAmount,
          'category': 'Bonus', // 🚀 Update: 'Bonus' कैटेगरी का उपयोग करें
          'item': 'Bonus / Extra Income (${DateFormat('MMM d').format(DateTime.now())})',
          'timestamp': FieldValue.serverTimestamp(),
        });


        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Safelata! ₹${newIncomeAmount.toStringAsFixed(2)} ka extra income ${_getMonthName(_selectedMonth)} ${_selectedYear} mein jod diya gaya hai.'
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Income save karne mein truti hui: $e')),
          );
        }
      }
    }
  }


  // Helper: Transaction Deletion (Updated for Bonus category)
  Future<void> _deleteTransaction(String transactionId, double amount, String category) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Len-Den Hataein'), content: const Text('Kya aap waqai is len-den ko hatana chahte hain?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Nahi')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Haan')),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final docId = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
        final monthlyDocRef = _firestore.collection('users').doc(user.uid).collection('monthly_records').doc(docId);

        await monthlyDocRef.collection('transactions').doc(transactionId).delete();

        // 🚀 Update: Income deletion logic for both Salary (if ever added as transaction) and Bonus
        if (category == 'Salary' || category == 'Bonus') {
          final newTotalSalary = FieldValue.increment(-amount);
          final newExtraIncome = category == 'Bonus' ? FieldValue.increment(-amount) : FieldValue.increment(0); // Only decrement extraIncome if it was a Bonus

          // If the deleted transaction was the base salary transaction (which we are not creating for now,
          // but covering for safety), then handle it. Otherwise, assume 'Bonus' decreases extraIncome.

          // Simplified logic: If it's income, decrease totalSalary. If it's explicitly 'Bonus', also decrease extraIncome.
          await monthlyDocRef.update({
            'totalSalary': newTotalSalary,
            'extraIncome': newExtraIncome,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

        } else {
          // Expense deletion logic
          final newSpent = FieldValue.increment(-amount);
          await monthlyDocRef.update({
            '${category}Spent': newSpent, 'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Len-Den safaltapoorvak hata diya gaya.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Len-Den hatane mein truti hui: $e')));
        }
      }
    }
  }

  // Helper: Month Name (No changes)
  String _getMonthName(int month) {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month];
  }

  // Helper: Category Icon (Updated for Bonus)
  IconData _getCategoryIcon(String category, [String? subCategory]) {
    if (category == 'Salary') {
      return Icons.paid_outlined;
    }
    if (category == 'Bonus') {
      return Icons.star_border_outlined; // Bonus icon
    }
    switch (category) {
      case 'Needs': return Icons.shopping_bag_outlined;
      case 'Wants': return Icons.movie_creation_outlined;
      case 'Saving': return Icons.account_balance_wallet_outlined;
      default: return Icons.local_atm;
    }
  }


  List<Widget> get _screens {
    if (_currentUser == null) {
      // Show loading or login message if user is null
      return [
        const Center(child: Text('Login ki prateeksha hai...', style: TextStyle(fontSize: 20))),
        const Center(child: Text('Login ki prateeksha hai...')),
        const Center(child: Text('Login ki prateeksha hai...')),
        const Center(child: Text('Login ki prateeksha hai...')),
        const Center(child: Text('Login ki prateeksha hai...')),
      ];
    }

    return [
      HomeBody( // 0: होम
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
        onMonthChanged: (month) {
          setState(() { _selectedMonth = month; _setupDataStreams(); });
        },
        onYearChanged: (year) {
          setState(() { _selectedYear = year; _selectedMonth = DateTime.now().month; _setupDataStreams(); });
        },
        userCreationDate: _userCreationDate,
        monthlyDataStream: _monthlyDataStream,
        transactionsStream: _transactionsStream,
        // 🚀 Update: Passing the two new functions
        setBaseSalary: _showBaseSalaryDialog,
        addExtraIncome: _showExtraIncomeDialog,
        // ------------------------------------
        deleteTransaction: _deleteTransaction,
        getCategoryIcon: _getCategoryIcon,
        getMonthName: _getMonthName,
      ),
      AnalysisScreen( // 1: रिपोर्ट्स
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
        onMonthChanged: (month) {
          setState(() { _selectedMonth = month; _setupDataStreams(); });
        },
        onYearChanged: (year) {
          setState(() { _selectedYear = year; _selectedMonth = DateTime.now().month; _setupDataStreams(); });
        },
      ),

      const GoalSettingScreen(), // 2: लक्ष्य (Goals)
      const Center(child: Text('सूचनाएँ (Notifications Screen)')), // 3: सूचनाएँ

      // UPDATED: ProfileScreen को सिर्फ आवश्यक पैरामीटर्स पास करें
      ProfileScreen( // 4: प्रोफ़ाइल
        currentUser: _currentUser,
        userName: _userName,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          if (user == null) {
            _selectedIndex = 0;
            _userName = null;
          }
        });
        if (user != null) {
          _initializeUserDate(user);
        } else {
          // If logged out, reset streams explicitly
          _setupDataStreams();
        }
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  // MARK: - Firebase Setup

  void _initializeUserDate(User user) {
    if (mounted) {
      setState(() {
        _userName = user.displayName ?? user.email ?? 'Mehamaan';
      });
      _userCreationDate = user.metadata.creationTime;
      final now = DateTime.now();
      setState(() {
        _selectedMonth = now.month;
        _selectedYear = now.year;
      });
      _setupDataStreams();
    }
  }

  void _setupDataStreams() {
    final user = _currentUser;
    if (user != null) {
      final docId = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      _monthlyDataStream = _firestore
          .collection('users').doc(user.uid).collection('monthly_records').doc(docId).snapshots();

      _transactionsStream = _firestore
          .collection('users').doc(user.uid).collection('monthly_records').doc(docId)
          .collection('transactions').orderBy('timestamp', descending: true).snapshots();
    } else {
      // Clear streams if user logs out
      setState(() {
        _monthlyDataStream = null;
        _transactionsStream = null;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFFFFD700);
    const unselectedColor = Color(0xFF999999);

    // Theme data now relies on context
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final darkBackgroundColor = isDarkMode ? const Color(0xFF1a1a1a) : Colors.white;
    final bottomBarColor = isDarkMode ? const Color(0xFF2a2a2a) : Colors.white;

    // Use a light status bar style if the background is dark (or vice versa)
    final SystemUiOverlayStyle systemOverlayStyle = isDarkMode
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    // यदि यूज़र लॉग इन नहीं है, तो लॉगिन स्क्रीन दिखाएँ (वर्तमान में एक लोडिंग स्क्रीन)
    if (_currentUser == null) {
      // TODO: यहां LoginScreen को कॉल करना है
      return Scaffold(
        backgroundColor: darkBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFFFD700)),
              const SizedBox(height: 20),
              Text(
                'Login ki prateeksha hai...',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18),
              ),
              const SizedBox(height: 5),
              Text(
                'If this persists, please ensure you are logged in.',
                style: TextStyle(color: isDarkMode ? Colors.grey : Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: Scaffold(
        backgroundColor: darkBackgroundColor,

        body: Column(
          children: [
            // Custom Top Bar (Gradient)
            Container(
              height: 88,
              padding: const EdgeInsets.only(top: 44, left: 24, right: 24, bottom: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                      'My Salary',
                      style: TextStyle(
                          color: Color(0xFF1a1a1a),
                          fontSize: 20, fontWeight: FontWeight.w700
                      )
                  ),
                  GestureDetector(
                    onTap: () => _onItemTapped(4), // Navigate to Profile (Index 4)
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 14),
                    ),
                  ),
                ],
              ),
            ),
            // Main content area
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
            ),
          ],
        ),

        floatingActionButton: StreamBuilder<DocumentSnapshot>(
          stream: _monthlyDataStream,
          builder: (context, snapshot) {
            final data = snapshot.hasData && snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : {};
            final totalSalary = (data['totalSalary'] ?? 0.0).toDouble();
            final needsSpent = (data['NeedsSpent'] ?? 0.0).toDouble();
            final wantsSpent = (data['WantsSpent'] ?? 0.0).toDouble();
            final savingsSpent = (data['SavingSpent'] ?? 0.0).toDouble();

            return FloatingActionButton(
              heroTag: "addExpenseFAB",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseScreen(
                      totalSalary: totalSalary, needsSpent: needsSpent,
                      wantsSpent: wantsSpent, savingsSpent: savingsSpent,
                    ),
                  ),
                );
              },
              backgroundColor: const Color(0xFFFFD700),
              shape: const CircleBorder(),
              elevation: 8,
              child: const Icon(Icons.add, color: Color(0xFF1a1a1a), size: 30),
            );
          },
        ),

        bottomNavigationBar: Container(
          height: 84,
          decoration: BoxDecoration(
            color: bottomBarColor,
            border: Border(top: BorderSide(color: isDarkMode ? const Color(0xFF444444) : const Color(0xFFf0f0f0), width: 1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
            ],
          ),
          child: BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
              BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Goals'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: selectedColor,
            unselectedItemColor: unselectedColor,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            showUnselectedLabels: true,
          ),
        ),
      ),
    );
  }
}