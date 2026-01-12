import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart'; // Reminders को कैंसिल करने के लिए जोड़ा गया है।

// ✅ FIX/DEBUG: __app_id को सीधे उपयोग करें या डिफ़ॉल्ट प्रदान करें।
const String kDefaultAppId = 'default-app-id';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          currentUser = user;
          if (user == null) {
            debugPrint('[AUTH DEBUG] User is not authenticated for Notifications Screen.');
          } else {
            debugPrint('[AUTH DEBUG] User authenticated: ${user.uid}');
          }
        });
      }
    });
    currentUser = _auth.currentUser;
  }

  Color _getContrastColor(BuildContext context, {double opacity = 1.0}) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(opacity);
  }

  // --- Firestore Collection Path Getter ---
  CollectionReference<Map<String, dynamic>> _getCollectionReference(String collectionName) {
    if (currentUser == null) {
      return _firestore.collection('dummy_path');
    }

    final appId = const String.fromEnvironment('APP_ID', defaultValue: kDefaultAppId);

    return _firestore
        .collection('artifacts')
        .doc(appId)
        .collection('users')
        .doc(currentUser!.uid)
        .collection(collectionName);
  }
  // --- END Collection Helper ---

  // --- 1. बिल रिमाइंडर्स स्ट्रीम (Alerts Stream) ---
  Stream<QuerySnapshot> _getBillRemindersStream() {
    if (currentUser == null) return const Stream.empty();
    return _getCollectionReference('user_bills')
        .where('isActive', isEqualTo: true)
        .orderBy('dayOfMonth', descending: false)
        .snapshots();
  }

  // --- 2. बिल रिमाइंडर कार्ड (Bill Reminder Card - Enhanced UI) ---
  Widget _buildBillReminderCard(DocumentSnapshot billDoc) {
    try {
      final data = (billDoc.data() ?? {}) as Map<String, dynamic>;
      final today = DateTime.now();
      final BuildContext context = this.context;
      final cs = Theme.of(context).colorScheme;

      final String name = data['name'] ?? 'Bill';
      final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final int dayOfMonth = (data['dayOfMonth'] as int?) ?? 1;
      final bool receiveReminders = data['receiveReminders'] ?? true;

      if (!receiveReminders) {
        return const SizedBox.shrink();
      }

      // अगले नियत तारीख की गणना
      DateTime calculateNextDueDate(DateTime referenceDate, int day) {
        try {
          DateTime proposedDateThisMonth = DateTime(referenceDate.year, referenceDate.month, day);
          if (referenceDate.day <= day) {
            return proposedDateThisMonth;
          } else {
            return DateTime(referenceDate.year, referenceDate.month + 1, day);
          }
        } catch (e) {
          return DateTime(referenceDate.year, referenceDate.month + 1, 1);
        }
      }

      DateTime nextDue = calculateNextDueDate(today, dayOfMonth);
      final remainingDays = nextDue.difference(today).inDays;

      // ✅ ALERT FILTER CHECK (केवल 7 दिन विलंबित से 30 दिन आगामी तक दिखाएँ)
      if (remainingDays < -7 || remainingDays > 30) {
        return const SizedBox.shrink();
      }

      Color alertColor;
      String statusMessage;
      IconData statusIcon;
      bool isOverdueOrDueToday = false;

      if (remainingDays < 0) {
        // विलंबित (Overdue)
        alertColor = Colors.red.shade700;
        statusMessage = 'विलंबित: ${remainingDays.abs()} दिन पहले';
        statusIcon = Icons.report_problem_rounded;
        isOverdueOrDueToday = true;
      } else if (remainingDays == 0) {
        // आज नियत (Due Today)
        alertColor = Colors.orange.shade700;
        statusMessage = 'आज नियत (DUE TODAY)!';
        statusIcon = Icons.warning_amber_rounded;
        isOverdueOrDueToday = true;
      } else if (remainingDays <= 7) {
        // 7 दिन या उससे कम बाकी
        alertColor = Colors.orange.shade400;
        statusMessage = '🚨 ${remainingDays} दिन बाकी हैं';
        statusIcon = Icons.schedule;
      } else {
        // 7 से 30 दिन बाकी
        alertColor = cs.primary;
        statusMessage = 'नियत तारीख: ${DateFormat('dd MMM').format(nextDue)}';
        statusIcon = Icons.notifications_active;
      }

      final Color titleColor = _getContrastColor(context, opacity: 1.0);
      final Color subtitleColor = _getContrastColor(context, opacity: 0.7);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(15),
          border: isOverdueOrDueToday
              ? Border.all(color: alertColor.withOpacity(0.5), width: 2) // Urgent items have a strong border
              : null,
          boxShadow: [
            BoxShadow(
              color: isOverdueOrDueToday ? alertColor.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Container - Larger and more defined
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: alertColor, size: 28),
            ),
            const SizedBox(width: 15),

            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusMessage,
                    style: TextStyle(
                      color: isOverdueOrDueToday ? alertColor : subtitleColor,
                      fontSize: 13,
                      fontWeight: isOverdueOrDueToday ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '₹${NumberFormat('#,##0').format(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w900, // Extra bold
                fontSize: 18,
                color: isOverdueOrDueToday ? alertColor : cs.primary,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[ERROR] Error processing bill reminder card for ${billDoc.id}: $e');
      return const SizedBox.shrink();
    }
  }


  // --- 3. गोल चेतावनी स्ट्रीम (Goal Warning Stream) ---
  Stream<QuerySnapshot> _getGoalWarningsStream() {
    if (currentUser == null) return const Stream.empty();
    return _getCollectionReference('saving_goals')
        .where('isCompleted', isEqualTo: false)
        .snapshots();
  }

  // --- 4. गोल चेतावनी कार्ड (Goal Warning Card - Enhanced UI) ---
  Widget _buildGoalWarningCard(DocumentSnapshot goalDoc) {
    try {
      final data = (goalDoc.data() ?? {}) as Map<String, dynamic>;
      final today = DateTime.now();
      final BuildContext context = this.context;
      final cs = Theme.of(context).colorScheme;

      final String name = data['name'] ?? 'Saving Goal';
      final double targetAmount = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;
      final double achievedAmount = (data['achievedAmount'] as num?)?.toDouble() ?? 0.0;
      final DateTime targetDate = (data['targetDate'] as Timestamp?)?.toDate() ?? today.add(const Duration(days: 365));

      final remainingAmount = targetAmount - achievedAmount;
      final daysToTarget = targetDate.difference(today).inDays;
      final monthsToTarget = daysToTarget / 30.44;

      // ✅ GOAL FILTER CHECK
      if (remainingAmount <= 0.01 || daysToTarget < -60) {
        return const SizedBox.shrink();
      }

      final requiredMonthly = monthsToTarget > 0.5 ? remainingAmount / monthsToTarget : remainingAmount;

      Color alertColor = cs.primary;
      String statusMessage = '';
      IconData statusIcon = Icons.savings_outlined;
      bool isUrgent = false;

      if (daysToTarget > 0 && daysToTarget <= 30) {
        // डेडलाइन निकट (1 महीना बाकी)
        alertColor = daysToTarget <= 7 ? Colors.red.shade600 : Colors.orange.shade600;
        statusMessage = '🚨 डेडलाइन निकट! ${daysToTarget} दिन बाकी हैं।';
        statusIcon = Icons.access_time_filled;
        isUrgent = true;
      } else if (requiredMonthly > 100) {
        // मासिक योगदान आवश्यक है
        final lastDayOfMonth = DateTime(today.year, today.month + 1, 0);
        final daysLeftInMonth = lastDayOfMonth.difference(today).inDays;

        alertColor = daysLeftInMonth <= 10 ? Colors.red.shade400 : cs.secondary;
        statusMessage = 'मासिक योगदान: ₹${NumberFormat('#,##0').format(requiredMonthly.round())} ज़रूरी है।';
        statusIcon = Icons.payments_outlined;
        isUrgent = daysLeftInMonth <= 10;
      } else {
        // सामान्य प्रगति
        alertColor = Colors.green.shade400; // सामान्य के लिए हरा रंग
        statusMessage = 'ट्रैक पर: ${DateFormat('dd MMM yyyy').format(targetDate)} तक लक्ष्य।';
        statusIcon = Icons.trending_up;
      }

      final progress = targetAmount > 0 ? achievedAmount / targetAmount : 0.0;
      final Color titleColor = _getContrastColor(context, opacity: 1.0);
      final Color subtitleColor = _getContrastColor(context, opacity: 0.7);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(15),
          border: isUrgent
              ? Border.all(color: alertColor.withOpacity(0.5), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isUrgent ? alertColor.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon Container
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: alertColor, size: 28),
                ),
                const SizedBox(width: 15),

                // Title and Status Message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: titleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusMessage,
                        style: TextStyle(
                          color: isUrgent ? alertColor : subtitleColor,
                          fontSize: 13,
                          fontWeight: isUrgent ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Target Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'लक्ष्य राशि',
                      style: TextStyle(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₹${NumberFormat('#,##0').format(targetAmount)}',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: cs.primary),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 15),

            // Progress Bar Section - Enhanced Look
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: cs.onSurface.withOpacity(0.1),
                    color: isUrgent ? alertColor : Colors.green.shade500, // Goal progress should be generally green
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'बचा हुआ: ₹${NumberFormat('#,##0').format(remainingAmount.round())}',
                          style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% पूरा',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[ERROR] Error processing saving goal card for ${goalDoc.id}: $e');
      return const SizedBox.shrink();
    }
  }

  // --- 5. मुख्य बिल्ड विधि (Main Build Method) ---
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
              'कृपया सूचनाएं देखने के लिए लॉग इन करें।',
              style: TextStyle(color: _getContrastColor(context))
          ),
        ),
      );
    }

    final primaryTextColor = _getContrastColor(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
            'सूचनाएं और अलर्ट',
            style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w900, fontSize: 22) // Bold Title
        ),
        backgroundColor: colorScheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CRITICAL DEBUG CHECK (लाल रंग में UID) ---
            Text(
                'DEBUG: Firestore Base Path (Expected) is artifacts/${kDefaultAppId}/users/${currentUser!.uid}/...',
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 10)
            ),
            const SizedBox(height: 20),
            // --- End DEBUG CHECK ---

            // ===================================================
            // --- Bill Reminders Section Header ---
            // ===================================================
            Container(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                  'मासिक बिल नियत तारीख अलर्ट',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.primary)
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 4, bottom: 15),
              child: Text(
                'आगामी 30 दिनों में नियत बिल और 7 दिनों तक विलंबित बिल।',
                style: TextStyle(fontSize: 14, color: primaryTextColor.withOpacity(0.6)),
              ),
            ),

            // --- Bill Reminders List ---
            StreamBuilder<QuerySnapshot>(
              stream: _getBillRemindersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (snapshot.hasError) {
                  debugPrint('[FIREBASE ERROR] Bill Alert Stream failed: ${snapshot.error}');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                        'डेटा लोड करने में त्रुटि। कृपया कंसोल जाँचें (Indexing Error)।',
                        style: TextStyle(color: Colors.red)
                    ),
                  );
                }

                final billDocs = snapshot.data?.docs ?? [];
                final billReminders = billDocs
                    .map((doc) => _buildBillReminderCard(doc))
                    .where((widget) => widget is! SizedBox)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (billReminders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Text(
                              '🎉 कोई लंबित या आगामी बिल अलर्ट नहीं। सब ठीक है!',
                              style: TextStyle(color: primaryTextColor.withOpacity(0.6), fontStyle: FontStyle.italic)
                          ),
                        ),
                      ),
                    ...billReminders
                  ],
                );
              },
            ),

            const SizedBox(height: 30),
            const Divider(height: 2, color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 30),


            // ===================================================
            // --- Goal Warnings Section Header ---
            // ===================================================
            Container(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                  'लक्ष्य और बचत चेतावनी',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.primary)
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 4, bottom: 15),
              child: Text(
                'लक्ष्यों की प्रगति और मासिक योगदान की आवश्यकता के अलर्ट।',
                style: TextStyle(fontSize: 14, color: primaryTextColor.withOpacity(0.6)),
              ),
            ),

            // --- Goal Warnings List ---
            StreamBuilder<QuerySnapshot>(
              stream: _getGoalWarningsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (snapshot.hasError) {
                  debugPrint('[FIREBASE ERROR] Goal Stream failed: ${snapshot.error}');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                        'डेटा लोड करने में त्रुटि। कृपया कंसोल जाँचें।',
                        style: TextStyle(color: Colors.red)
                    ),
                  );
                }

                final goalDocs = snapshot.data?.docs ?? [];
                final goalWarnings = goalDocs
                    .map((doc) => _buildGoalWarningCard(doc))
                    .where((widget) => widget is! SizedBox)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (goalWarnings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Text(
                              '✅ कोई सक्रिय लक्ष्य चेतावनी नहीं। आप अपनी बचत के साथ ट्रैक पर हैं!',
                              style: TextStyle(color: primaryTextColor.withOpacity(0.6), fontStyle: FontStyle.italic)
                          ),
                        ),
                      ),
                    ...goalWarnings
                  ],
                );
              },
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}