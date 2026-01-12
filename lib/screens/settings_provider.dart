import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// यह क्लास ऐप के थीम मोड (लाइट/डार्क) और भाषा (Locale) को प्रबंधित करती है।
class SettingsProvider with ChangeNotifier {
  // 1. Theme Mode State
  ThemeMode _themeMode = ThemeMode.system; // डिफ़ॉल्ट रूप से सिस्टम सेटिंग

  ThemeMode get themeMode => _themeMode;

  // Constructor: Provider बनने पर सहेजी गई भाषा लोड करें
  SettingsProvider() {
    _loadPreferredLocale();
    // थीम मोड को भी लोड करने के लिए आप यहाँ _loadPreferredTheme() जोड़ सकते हैं।
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // 2. Language/Locale State
  Locale? _locale;

  Locale? get locale => _locale;

  // SharedPreferences से पिछली सहेजी गई भाषा लोड करता है
  void _loadPreferredLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString('languageCode');

    if (languageCode != null) {
      // सहेजे गए कोड के आधार पर Locale सेट करें
      if (languageCode == 'hi') {
        _locale = const Locale('hi', 'IN');
      } else if (languageCode == 'en') {
        _locale = const Locale('en', 'US');
      } else {
        _locale = null; // यदि कोई अज्ञात कोड है, तो सिस्टम डिफ़ॉल्ट का उपयोग करें
      }
    } else {
      // यदि कोई भाषा सहेजी नहीं गई है, तो डिफ़ॉल्ट रूप से English सेट करें।
      _locale = const Locale('en', 'US');
    }
    notifyListeners();
  }


  // Hindi, English, या null (system)
  void setLanguage(String? languageCode) async {
    // अगर वही भाषा पहले से सेट है, तो कुछ न करें
    if (_locale?.languageCode == languageCode) return;

    final prefs = await SharedPreferences.getInstance();

    if (languageCode == 'hi') {
      _locale = const Locale('hi', 'IN');
      await prefs.setString('languageCode', 'hi');
    } else if (languageCode == 'en') {
      _locale = const Locale('en', 'US');
      await prefs.setString('languageCode', 'en');
    } else {
      _locale = null; // System default
      await prefs.remove('languageCode'); // सहेजे गए मान को हटा दें
    }

    notifyListeners();
  }
}