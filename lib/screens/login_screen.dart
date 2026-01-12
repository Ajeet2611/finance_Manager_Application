import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_screen.dart';
import 'home_screen.dart'; // Import the home screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMeState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberMeState() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? rememberMe = prefs.getBool('rememberMe');
    final String? email = prefs.getString('email');
    if (rememberMe != null && rememberMe) {
      setState(() {
        _rememberMe = rememberMe;
      });
      if (email != null) {
        _emailController.text = email;
      }
    }
  }

  // Custom SnackBar function
  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // Check if the user's email is verified
        if (userCredential.user != null && !userCredential.user!.emailVerified) {
          await _auth.signOut();
          _showSnackBar('कृपया लॉगिन करने से पहले अपना ईमेल सत्यापित करें।', true);
          return;
        }

        _showSnackBar('लॉगिन सफल!', false);

        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setBool('rememberMe', true);
          await prefs.setString('email', _emailController.text);
        } else {
          await prefs.setBool('rememberMe', false);
          await prefs.remove('email');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-email' || e.code == 'invalid-credential') {
          _showSnackBar('गलत ईमेल या पासवर्ड। कृपया पुनः प्रयास करें।', true);
        } else {
          _showSnackBar(e.message ?? 'एक त्रुटि हुई', true);
        }
      }
    }
  }

  // New function to handle forgot password
  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnackBar('पासवर्ड रीसेट के लिए कृपया अपना ईमेल दर्ज करें।', true);
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text);
      _showSnackBar('पासवर्ड रीसेट ईमेल भेज दिया गया है। कृपया अपना इनबॉक्स देखें।', false);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'एक त्रुटि हुई', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: screenHeight * 0.03),
                Image.asset('assets/login_bg.jpg', height: screenHeight * 0.25, fit: BoxFit.contain),
                SizedBox(height: screenHeight * 0.03),
                const Text('WELLCOME TO FINANCE MANAGER', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                SizedBox(height: screenHeight * 0.05),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Plese enter your email id';
                    }
                    // Add email format validation using a regular expression
                    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                      return 'Please enter your valid email id';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your Name';
                    }
                    if (value.length < 6) {
                      return 'पासवर्ड कम से कम 6 अक्षर का होना चाहिए';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (bool? value) {
                            setState(() {
                              _rememberMe = value!;
                            });
                          },
                        ),
                        const Text('Remember me'),
                      ],
                    ),
                    TextButton(
                        onPressed: _handleForgotPassword, // Call the new function
                        child: const Text('Forget Password', style: TextStyle(color: Colors.blue))
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.03),

                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Login'),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                  },
                  child: const Text("sing up ", style: TextStyle(color: Colors.black54)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
