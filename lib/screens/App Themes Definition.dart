import 'package:flutter/material.dart';

// यहाँ आपके ऐप के लिए लाइट और डार्क थीम परिभाषित की गई है

final lightTheme = ThemeData(
  brightness: Brightness.light,
  // Primary (मुख्य) रंग
  primaryColor: Colors.blue.shade700,
  colorScheme: ColorScheme.light(
    primary: Colors.blue.shade700,
    surface: Colors.white,           // Scaffold/Background
    onSurface: Colors.black,         // Text color on light surface
    background: Colors.grey.shade50,
  ),
  cardColor: Colors.white,           // Card background color
  scaffoldBackgroundColor: Colors.grey.shade50,

  // टेक्स्ट थीम: डिफ़ॉल्ट रूप से काला (Black)
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black87),
  ),
);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  // Primary (मुख्य) रंग
  primaryColor: Colors.blue.shade300,
  colorScheme: ColorScheme.dark(
    primary: Colors.blue.shade300,
    surface: Colors.grey.shade800,   // Scaffold/Card/Background
    onSurface: Colors.white,         // Text color on dark surface
    background: Colors.grey.shade900,
  ),
  cardColor: Colors.grey.shade800,   // Card background color
  scaffoldBackgroundColor: Colors.grey.shade900,

  // टेक्स्ट थीम: डिफ़ॉल्ट रूप से सफेद (White)
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
  ),
);