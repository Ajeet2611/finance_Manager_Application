import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isDarkMode;

  const EditProfileScreen({super.key, required this.isDarkMode});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // वर्तमान उपयोगकर्ता का नाम टेक्स्ट फ़ील्ड में भरें
    final initialName = _auth.currentUser?.displayName ?? '';
    _nameController.text = initialName;
    print('BUILD: EditProfileScreen initialized. Initial name: $initialName');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- प्रोफ़ाइल फोटो अपलोड लॉजिक ---
  Future<void> _pickAndUploadImage() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('यूज़र लॉग इन नहीं है।')),
        );
      }
      return;
    }

    try {
      // 1. गैलरी से फोटो चुनें
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);

      if (pickedFile == null) {
        print('DEBUG: Image selection cancelled.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // 2. Firebase Storage में अपलोड करें
      final file = File(pickedFile.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('${user.uid}.jpg'); // UID के आधार पर फ़ाइल का नाम दें

      await storageRef.putFile(file);
      print('DEBUG: File uploaded to Firebase Storage.');

      // 3. डाउनलोड URL प्राप्त करें
      final photoUrl = await storageRef.getDownloadURL();
      print('DEBUG: Download URL obtained: $photoUrl');

      // 4. Firebase Auth प्रोफ़ाइल को अपडेट करें
      await user.updatePhotoURL(photoUrl);
      print('DEBUG: Firebase Auth photoURL updated.');

      // 5. स्थानीय प्रोफ़ाइल डेटा रीलोड करें
      await user.reload();
      print('DEBUG: Firebase user reloaded after photo update.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('प्रोफ़ाइल फोटो सफलतापूर्वक अपडेट हो गई!')),
        );
        // सफलता पर 'true' return करें ताकि ProfileScreen रीफ़्रेश हो
        Navigator.of(context).pop(true);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('अपलोड में Firebase त्रुटि: ${e.message}')),
        );
      }
      print('ERROR: Firebase Storage/Auth update failed: $e');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('प्रोफ़ाइल फोटो अपडेट करने में कोई अज्ञात त्रुटि हुई।')),
        );
      }
      print('ERROR: Unknown error in _pickAndUploadImage: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- प्रोफ़ाइल जानकारी अपडेट करें (नाम अपडेट लॉजिक) ---
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      print('DEBUG: Validation failed.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newName = _nameController.text.trim();
      final user = _auth.currentUser;
      print('DEBUG: Trying to update name to: $newName');

      // केवल तभी अपडेट करें जब नाम बदला गया हो और user null न हो
      if (user != null && newName != (user.displayName ?? '')) {
        await user.updateDisplayName(newName);
        print('DEBUG: updateDisplayName successful. Name set to: $newName');

        // महत्वपूर्ण: अपडेट के बाद डेटा को फ़ोर्स रीलोड करें
        await user.reload();
        print('DEBUG: Firebase user reloaded after update.');
      } else {
        print('DEBUG: Name is the same or user is null. No update needed.');
      }

      if (mounted) {
        // सफलता पर 'true' return करें ताकि ProfileScreen रीफ़्रेश हो
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('प्रोफ़ाइल सफलतापूर्वक अपडेट हो गई!')),
        );
        print('DEBUG: Successfully popped EditProfileScreen.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('प्रोफ़ाइल अपडेट करने में त्रुटि: $e')),
        );
      }
      print('ERROR: Update failed in _updateProfile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI को तुरंत अपडेट करने के लिए _auth.currentUser को सीधे यहाँ कॉल करें
    final user = _auth.currentUser;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final iconColor = widget.isDarkMode ? const Color(0xFFFFD700) : Colors.blueGrey;
    final backgroundColor = widget.isDarkMode ? const Color(0xFF1a1a1a) : Colors.white;

    final currentPhotoUrl = user?.photoURL;
    // ❌ त्रुटि निवारण: NetworkImage से 'key' पैरामीटर हटाया गया
    final profileImage = currentPhotoUrl != null
        ? NetworkImage(currentPhotoUrl)
        : null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('प्रोफ़ाइल Edit Karein', style: TextStyle(color: textColor)),
        backgroundColor: backgroundColor,
        foregroundColor: iconColor,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo Section
              GestureDetector(
                onTap: _pickAndUploadImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: iconColor.withOpacity(0.1),
                  backgroundImage: profileImage as ImageProvider<Object>?,
                  child: profileImage == null ? Icon(Icons.person, size: 70, color: iconColor) : null,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _pickAndUploadImage,
                child: Text('प्रोफ़ाइल फोटो Badlein', style: TextStyle(color: iconColor)),
              ),
              const SizedBox(height: 30),

              // Name Input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Aapka Naam',
                  prefixIcon: Icon(Icons.badge, color: iconColor),
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: iconColor, width: 2),
                  ),
                ),
                style: TextStyle(color: textColor),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'नाम खाली नहीं हो सकता';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Email Display (Non-Editable)
              TextFormField(
                initialValue: user?.email ?? 'N/A',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Email Address (Badla nahi ja sakta)',
                  prefixIcon: Icon(Icons.email, color: iconColor.withOpacity(0.5)),
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                  fillColor: backgroundColor,
                  filled: true,
                ),
                style: TextStyle(color: textColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 40),

              // Save Button
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFFFFD700))
                  : ElevatedButton.icon(
                onPressed: _updateProfile,
                icon: const Icon(Icons.save),
                label: const Text('Badlav Save Karein'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}