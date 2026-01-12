import 'package:flutter/material.dart';
import 'package:finance_vanager_app_v3/l10n/app_localizations.dart';
// यह विजेट सुनिश्चित करता है कि l10n ऑब्जेक्ट हमेशा उपलब्ध रहे
class BaseScreen extends StatelessWidget {
  final Widget child;

  const BaseScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // हर स्क्रीन में बार-बार 'AppLocalizations.of(context)' लिखने से बचें
    return LocalizationsHelper(
      child: child,
    );
  }
}

// यह InheritedWidget/Provider का हल्का वर्जन है
class LocalizationsHelper extends InheritedWidget {
  final AppLocalizations l10n;

  const LocalizationsHelper({
    super.key,
    required super.child,
  }) : l10n = AppLocalizations.of(child.context)!; // l10n ऑब्जेक्ट प्राप्त करें

  // l10n ऑब्जेक्ट को context के माध्यम से आसानी से एक्सेस करने के लिए एक स्टेटिक मेथड
  static AppLocalizations of(BuildContext context) {
    final helper = context.dependOnInheritedWidgetOfExactType<LocalizationsHelper>();
    if (helper == null) {
      throw FlutterError('LocalizationsHelper not found in context.');
    }
    return helper.l10n;
  }

  @override
  bool updateShouldNotify(LocalizationsHelper oldWidget) {
    // जब तक Locale (भाषा) नहीं बदलती, तब तक इसे अपडेट करने की ज़रूरत नहीं है
    return false;
  }
}