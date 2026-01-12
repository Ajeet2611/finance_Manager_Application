// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'वित्तीय प्रबंधक';

  @override
  String get welcomeTitle => 'आपकी वित्तीय यात्रा में आपका स्वागत है।';

  @override
  String get loginButton => 'लॉग इन करें';

  @override
  String get signupButton => 'खाता बनाएँ';

  @override
  String get homeTitle => 'डैशबोर्ड';

  @override
  String get addTransaction => 'Add Transaction';

  @override
  String get totalIncome => 'Total Income';

  @override
  String get totalExpense => 'Total Expense';

  @override
  String get balance => 'Current Balance';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get buttonLogin => 'Login';

  @override
  String get textFieldEmail => 'Email';

  @override
  String get textFieldPassword => 'Password';

  @override
  String get checkboxRememberMe => 'Remember me';

  @override
  String get buttonForgetPassword => 'Forgot Password?';

  @override
  String get textSignupPrompt => 'Sign up';

  @override
  String get validationEnterEmail => 'Please enter your email ID';

  @override
  String get validationEnterValidEmail => 'Please enter a valid email ID';

  @override
  String get validationEnterPassword => 'Please enter your password';

  @override
  String get validationPasswordLength =>
      'Password must be at least 6 characters long';

  @override
  String get loginSuccess => 'Login successful!';

  @override
  String get loginVerifyEmailBeforeLogin =>
      'Please verify your email before logging in.';

  @override
  String get loginInvalidCredentials =>
      'Invalid email or password. Please try again.';

  @override
  String get loginGenericError => 'An error occurred during login.';

  @override
  String get forgotPasswordEnterEmail =>
      'Please enter your email to reset your password.';

  @override
  String get forgotPasswordEmailSent =>
      'Password reset email has been sent. Please check your inbox.';

  @override
  String get forgotPasswordGenericError =>
      'An error occurred while sending the reset email.';
}
