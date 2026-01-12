import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    // 💡 बदलाव: विलंब (delay) को 4 सेकंड पर सेट किया गया है (आपकी 3-5 सेकंड की सीमा के भीतर)।
    // यह सुनिश्चित करता है कि स्प्लैश स्क्रीन हमेशा कम से कम 4 सेकंड तक दिखेगी।
    Timer(const Duration(seconds: 4), () {
      // 4 सेकंड के बाद, यूज़र की ऑथेंटिकेशन स्थिति की जांच करें।
      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return; // यदि विजेट डिस्पोज हो गया है तो आगे नेविगेट न करें।

      if (user != null) {
        // यूज़र लॉग इन है, होम स्क्रीन पर नेविगेट करें।
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // यूज़र लॉग इन नहीं है, वेलकम स्क्रीन पर नेविगेट करें।
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 💡 सुधार: रंग थीम-अवेयर बनाएं (main.dart की थीम के अनुरूप)।
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      // पृष्ठभूमि (Background) रंग main.dart की थीम से लें
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animation
            Lottie.asset(
              'assets/animations/lottie_animation.json',
              width: 300,
              height: 300,
              fit: BoxFit.contain,
              repeat: false, // Animation एक बार चलाकर रुक जाए
            ),
            const SizedBox(height: 20),
            Text(
              'Finance Manager',
              style: TextStyle(
                fontSize: 28, // फ़ॉन्ट साइज़ बढ़ाया गया
                fontWeight: FontWeight.bold,
                // 💡 सुधार: टेक्स्ट रंग थीम के अनुसार सेट करें
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 40),
            // लोडिंग इंडिकेटर (UX के लिए)
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}