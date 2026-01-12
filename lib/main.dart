import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Localization import
import 'package:finance_vanager_app_v3/l10n/app_localizations.dart';

// App imports
import 'screens/splash_screen.dart';
import 'screens/settings_provider.dart';

// 🔔 Notification Service Import (Needed for setup and initial check)
import 'screens/notification_service.dart';

// =========================================================
// ✅ मुख्य `main()` फंक्शन: सभी शुरुआती सेटअप को संभालता है
// =========================================================
void main() async {
  // 1. सुनिश्चित करें कि Flutter Widgets तैयार हैं
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase को शुरू करें
  await Firebase.initializeApp();

  // 3. 🔔 नोटिफिकेशन सर्विस को शुरू करें
  await NotificationService.initialize(); // यह कॉल OS के साथ कनेक्शन बनाता है

  // 4. 🚀 प्रारंभिक नोटिफिकेशन चेक: यदि ऐप नोटिफिकेशन से लॉन्च हुआ है तो हैंडल करें
  // (यह मानते हुए कि NotificationService.getInitialNotification() को ठीक कर दिया गया है)
  final initialNotificationDetails = await NotificationService.getInitialNotification();
  if (initialNotificationDetails != null && initialNotificationDetails.didNotificationLaunchApp) {
    // यहाँ आप initialNotificationDetails.notificationResponse?.payload के आधार पर
    // यूज़र को संबंधित बिल स्क्रीन पर नेविगेट करने का लॉजिक डाल सकते हैं।
    debugPrint('App launched from notification with payload: ${initialNotificationDetails.notificationResponse?.payload}');
  }

  // 5. SettingsProvider को top level पर जोड़ें और ऐप चलाएँ
  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}
// =========================================================


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer का उपयोग करें ताकि ThemeMode या Locale बदलने पर MaterialApp rebuild हो
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Finance Manager',

          // 💡 Provider से ThemeMode प्राप्त करें
          themeMode: settings.themeMode,

          // --- 🚀 Localization Settings (भाषा बदलने के लिए आवश्यक) ---
          // 💡 Provider से Locale प्राप्त करें
          locale: settings.locale,

          supportedLocales: const [
            Locale('en', 'US'), // English
            Locale('hi', 'IN'), // Hindi
          ],

          // ✅ AppLocalizations.delegate का उपयोग
          localizationsDelegates: const [
            AppLocalizations.delegate, // <--- यह generated code को लोड करता है
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // --------------------------------------------------------

          // सामान्य (Light) थीम
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFFFFD700),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              color: Colors.white,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
              elevation: 0,
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFFFFD700),
            ),
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFFFD700),
              secondary: const Color(0xFFFFA500),
              surface: Colors.grey[100]!,
            ),
            useMaterial3: true,
          ),

          // डार्क थीम
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFFFFD700),
            scaffoldBackgroundColor: const Color(0xFF1a1a1a),
            appBarTheme: const AppBarTheme(
              color: Color(0xFF1a1a1a),
              iconTheme: IconThemeData(color: Color(0xFFFFD700)),
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              elevation: 0,
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFFFFD700),
            ),
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFFFFD700),
              secondary: const Color(0xFFFFA500),
              surface: const Color(0xFF2a2a2a),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
              labelLarge: TextStyle(color: Colors.white),
            ),
            useMaterial3: true,
          ),

          // 💡 बदलाव: सीधे SplashScreen को home पर सेट करें
          home: const SplashScreen(),
        );
      },
    );
  }
}