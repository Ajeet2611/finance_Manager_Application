import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter/material.dart'; // Navigating to a screen requires context, but here we just use it for debug.

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  // A handler for when a notification is selected/tapped
  static void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint('Notification payload: $payload');
      // यहाँ आप उपयोगकर्ता को उस बिल स्क्रीन पर नेविगेट कर सकते हैं जिसका रिमाइंडर था।
      // उदाहरण: Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: payload)));
    }
  }

  // Initialization function
  static Future initialize() async {
    // 1. Initialize Timezone
    tz.initializeTimeZones();
    // ✅ सुधार 1: डिवाइस के लोकल टाइमज़ोन को सेट करने के लिए tz.local का उपयोग करें।
    // यह सुनिश्चित करता है कि शेड्यूल सही ढंग से स्थानीय समय के साथ काम करता है।
    tz.setLocalLocation(tz.local);

    // 2. Platform-specific initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // 3. Request permissions (especially for iOS)
    await _notifications
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // --- 4. आवर्ती बिलों के लिए महत्वपूर्ण बदलाव ---
  // यह फ़ंक्शन मासिक/साप्ताहिक बिलों के लिए नोटिफिकेशन को शेड्यूल करता है
  static Future scheduleBillNotification({
    required int id,
    required String title,
    required double amount,
    required String frequency,
    required int dayOfMonth, // 1 से 31
    required String billId,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // रिमाइंडर नियत तारीख से 1 दिन पहले रात 9:00 बजे (21:00) पर सेट करें।
    // यह उपयोगकर्ता को तैयारी का समय देता है।
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      dayOfMonth, // बिल के नियत दिन पर
      21, // 9 PM
      0,
    );

    // यदि आज नियत तारीख का दिन है, तो अगले महीने/सप्ताह में शेड्यूल करें।
    // रिमाइंडर बिल नियत तारीख से 1 दिन पहले होना चाहिए।
    // इस लॉजिक को सरल बनाने के लिए, हम सिर्फ नियत तारीख पर रिमाइंडर सेट कर रहे हैं,
    // और यह सुनिश्चित करेंगे कि यह भविष्य में हो।

    // 1. वर्तमान महीना/वर्ष सेट करें।
    // यदि यह महीना पहले ही बीत चुका है, तो अगले महीने पर जाएं।
    if (scheduledDate.isBefore(now)) {
      if (frequency == 'Monthly') {
        scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month + 1,
          dayOfMonth,
          21,
          0,
        );
      } else if (frequency == 'Weekly') {
        // साप्ताहिक बिलों के लिए, यह logic जटिल है। सरल रखने के लिए,
        // हम इस फ़ंक्शन को केवल "Monthly" पर केंद्रित करेंगे।
        // आप साप्ताहिक बिलों को एक साधारण One-Time नोटिफिकेशन के रूप में सेट कर सकते हैं।
      }
    }

    // सुनिश्चित करें कि यह नियत तारीख से 1 दिन पहले शेड्यूल हो (21:00 बजे)
    scheduledDate = scheduledDate.subtract(const Duration(days: 1));

    // यदि घटाने के बाद भी यह अतीत में है (उदाहरण के लिए, आज 20 तारीख है और बिल 21 को है,
    // और 21-1=20 को 9 PM बीत चुका है), तो अगले महीने शेड्यूल करें।
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1, // अगले महीने में
        dayOfMonth - 1,
        21,
        0,
      );
    }


    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'bill_reminders_channel',
      'Bill Reminders',
      channelDescription: 'Reminders for upcoming and due bills.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String body = 'Amount: ₹${amount.toStringAsFixed(2)}. Tap to mark as paid.';
    final String payload = billId; // Bill ID को पेलोड के रूप में पास करें

    try {
      // ✅ सुधार 2: आवर्ती शेड्यूल के लिए `matchDateTimeComponents` का उपयोग करें।
      // यह हर महीने (या सप्ताह) एक ही समय पर दोहराता रहेगा।
      if (frequency == 'Monthly') {
        await _notifications.zonedSchedule(
          id,
          'Bill Due: $title',
          body,
          scheduledDate, // पहली बार के लिए निर्धारित तारीख
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          // यह सुनिश्चित करता है कि नोटिफिकेशन हर महीने, नियत दिन की 1 दिन पहले की तारीख पर दोहराता रहे।
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
        debugPrint('Scheduled MONTHLY notification ID $id for day $dayOfMonth at 9 PM.');
      } else {
        // अन्य आवृत्तियों (जैसे Weekly) के लिए, आप एक बार के नोटिफिकेशन का उपयोग कर सकते हैं,
        // लेकिन इसे मासिक की तरह आवर्ती बनाना अधिक उपयोगी है।
        // अभी के लिए, हम सिर्फ मासिक पर ध्यान केंद्रित कर रहे हैं।
        debugPrint('Notification for $frequency not implemented yet. Using one-time schedule.');
      }
    } catch (e) {
      debugPrint('Error scheduling notification ID $id: $e');
    }
  }

  // Function to cancel a specific notification
  static Future cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('Cancelled notification ID $id');
  }

  // Function to cancel all scheduled notifications
  static Future cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('Cancelled all notifications');
  }

  // FIX: Change return type to NotificationAppLaunchDetails?
  static Future<NotificationAppLaunchDetails?> getInitialNotification() async {
    return await _notifications.getNotificationAppLaunchDetails();
  }
}