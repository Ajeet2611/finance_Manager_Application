import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bill_setup_screen.dart';
import 'welcome_screen.dart';
import 'settings_provider.dart';
import 'edit_profile_screen.dart';

// 💡 State संभालने के लिए StatelessWidget से StatefulWidget में बदला गया
class ProfileScreen extends StatefulWidget {
  final String? userName;
  final User? currentUser;

  const ProfileScreen({
    super.key,
    this.userName,
    this.currentUser,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Helper widget for a custom List Tile
  Widget _buildProfileOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final iconColor = isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFFFA500);

    return InkWell(
      onTap: trailing == null ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2a2a2a) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.85), fontWeight: FontWeight.w500),
              ),
            ),
            trailing ?? Icon(Icons.arrow_forward_ios, color: textColor.withOpacity(0.4), size: 16),
          ],
        ),
      ),
    );
  }

  // 💡 बदलाव: EditProfileScreen से लौटने पर state को अपडेट करने का लॉजिक
  void _goToEditProfileScreen(BuildContext context, bool isDarkMode) async {
    // await का उपयोग करके देखें कि EditProfileScreen ने क्या return किया
    final bool? shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          isDarkMode: isDarkMode,
        ),
      ),
    );

    // यदि EditProfileScreen ने 'true' return किया, तो इसका मतलब है कि बदलाव हुए हैं।
    if (shouldRefresh == true) {
      // Firebase Auth user object को फिर से लोड करें ताकि latest photoURL मिल सके
      await FirebaseAuth.instance.currentUser?.reload();
      setState(() {
        // UI को latest डेटा के साथ रीबिल्ड करें
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 currentUser को widget.currentUser से प्राप्त करें
    if (widget.currentUser == null) {
      return const Center(child: Text('Login ki jaankari uplabdh nahi hai.'));
    }

    // सुनिश्चित करें कि हम हमेशा latest User data प्राप्त करें
    final currentUser = FirebaseAuth.instance.currentUser ?? widget.currentUser!;

    final userEmail = currentUser.email ?? 'N/A';
    final userNameDisplay = currentUser.displayName ?? widget.userName ?? 'Mehamaan';
    final userPhotoUrl = currentUser.photoURL;
    final _auth = FirebaseAuth.instance;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final iconColor = isDarkMode ? const Color(0xFFFFD700) : Colors.blueGrey;
    final backgroundColor = isDarkMode ? const Color(0xFF1a1a1a) : Colors.white;

    // ❌ त्रुटि निवारण: NetworkImage से 'key' पैरामीटर हटाया गया
    final ImageProvider? profileImageProvider = userPhotoUrl != null && userPhotoUrl.isNotEmpty
        ? NetworkImage(userPhotoUrl) as ImageProvider
        : null;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 50),

            // 1. User Avatar and Name
            GestureDetector(
              onTap: () => _goToEditProfileScreen(context, isDarkMode),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: iconColor.withOpacity(0.3),
                // Fixed Image Provider का उपयोग करें
                backgroundImage: profileImageProvider,
                child: profileImageProvider == null
                    ? Icon(Icons.person, size: 50, color: iconColor)
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // User Name
            Text(
              userNameDisplay,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor),
            ),

            // User Email
            Text(
              userEmail,
              style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.6)),
            ),

            // Edit Profile Button
            TextButton.icon(
              onPressed: () => _goToEditProfileScreen(context, isDarkMode),
              icon: const Icon(Icons.edit, size: 18, color: Color(0xFFFFA500)),
              label: const Text('Edit Profile', style: TextStyle(color: Color(0xFFFFA500))),
            ),


            const SizedBox(height: 40),

            // --- Settings Section ---
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 8, top: 20),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // 💡 1. Dark Mode Toggle
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                final isDark = settings.themeMode == ThemeMode.dark;
                return _buildProfileOption(
                  context: context,
                  icon: isDark ? Icons.light_mode : Icons.dark_mode,
                  title: 'Dark Mode',
                  onTap: () {},
                  trailing: Switch(
                    value: isDark,
                    onChanged: (value) {
                      settings.toggleTheme(value);
                    },
                    activeColor: const Color(0xFFFFD700),
                  ),
                );
              },
            ),

            // 💡 2. Language Change Dropdown
            _buildProfileOption(
              context: context,
              icon: Icons.language,
              title: 'Bhasha Badlein (Language)',
              onTap: () {},
              trailing: Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  final currentLang = settings.locale?.languageCode ?? 'system';
                  return DropdownButton<String>(
                    value: currentLang,
                    icon: Icon(Icons.arrow_drop_down, color: textColor),
                    underline: const SizedBox(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        settings.setLanguage(newValue == 'system' ? null : newValue);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bhasha safaltapoorvak badal di gayi.')),
                        );
                      }
                    },
                    items: <String>['system', 'en', 'hi']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value == 'en' ? 'English' : (value == 'hi' ? 'Hindi' : 'System Default'),
                          style: TextStyle(color: textColor.withOpacity(0.85), fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            // 3. Bill Setup Option
            _buildProfileOption(
              context: context,
              icon: Icons.repeat,
              title: 'Recurring Bill Setup',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BillSetupScreen()),
                );
              },
            ),
            // -----------------------------

            const SizedBox(height: 40),

            // 4. Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                onPressed: () async {
                  await _auth.signOut();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Safaltapoorvak log out ho gaye.')));

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                          (Route<dynamic> route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}