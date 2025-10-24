// profile_screen.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/styles/global_styles.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../styles/profile_styles.dart';
import '../providers/auth_provider.dart' as myAuth;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

extension ContextX on BuildContext {
  bool get isMounted => (this as Element).mounted;
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = firebase_auth.FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  String currentPassword = '';
  String newPassword = '';
  String confirmPassword = '';
  bool showCurrentPassword = false;
  bool showNewPassword = false;
  bool showConfirmPassword = false;
  bool agreedTerms = false;
  bool termsModalVisible = false;
  bool passwordNeedsReset = false;
  bool isNavigationBlocked = false;
  bool submitting = false;
  bool uploadingImage = false;
  bool _loading = true;

  final int currentTermsVersion = 1;

  Map<String, dynamic> passwordStrength = {
    'strength': '',
    'barWidth': 0.0,
    'barColor': Colors.transparent,
    'checks': {
      'hasLength': false,
      'hasUppercase': false,
      'hasLowercase': false,
      'hasNumber': false,
      'hasSymbol': false,
    },
  };
  bool showPasswordStrength = false;

  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
  final authProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);
  final user = authProvider.user;
  if (user == null) {
    if (!mounted) return;
    setState(() {
      _profileData = {
        'organization': 'Admin',
        'hq': 'N/A',
        'contactPerson': 'Unknown',
        'email': 'N/A',
        'mobile': 'N/A',
        'role': 'N/A',
        'profilePicture': '',
      };
      _loading = false;
    });
    return;
  }

  try {
    await authProvider.loadUserData();
    if (!mounted) return;
    final data = authProvider.userData ?? {};
    final address = data['address'] as Map<String, dynamic>?;
    final hqParts = [
      address?['barangay'],
      address?['city'],
      address?['province'],
      address?['region'],
    ].where((e) => e != null && e != 'N/A').toList();
    final hq = hqParts.isNotEmpty ? hqParts.join(', ') : 'N/A';

    setState(() {
      _profileData = {
        'organization': data['organization'] ?? 'Admin',
        'hq': hq,
        'contactPerson': data['contactPerson'] ?? 'Unknown',
        'email': data['email'] ?? user.email ?? 'N/A',
        'mobile': data['mobile'] ?? 'N/A',
        'role': authProvider.role ?? 'N/A',
        'profilePicture': data['profilePicture'] ?? '',
      };
      _loading = false;
    });

    final agreed = data['terms_agreed_version'] as int?;
    if (agreed == null || agreed < currentTermsVersion) {
      setState(() {
        termsModalVisible = true;
        isNavigationBlocked = true;
      });
    }

    if (data['password_needs_reset'] == true) {
      if (!mounted) return;
      setState(() {
        passwordNeedsReset = true;
        isNavigationBlocked = true;
      });
      _showInfoDialog(
        title: 'Password Change Required',
        message:
            'Thank you for accepting the Terms. For security, please change your password now.',
        icon: Icons.lock,
        iconColor: Colors.amber,
      );
    }
  } catch (e) {
    _showError('Failed to load profile: $e');
    setState(() {
      _profileData = {
        'organization': 'Admin',
        'hq': 'N/A',
        'contactPerson': 'Unknown',
        'email': user.email ?? 'N/A',
        'mobile': 'N/A',
        'role': 'N/A',
        'profilePicture': '',
      };
      _loading = false;
    });
  }
}

  void _handlePasswordInput(String password) {
    setState(() {
      newPassword = password;
      if (password.isEmpty) {
        showPasswordStrength = false;
        _resetPasswordStrength();
        return;
      }

      showPasswordStrength = true;
      final hasLength = password.length >= 8;
      final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      final hasNumber = RegExp(r'[0-9]').hasMatch(password);
      final hasSymbol = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
      final lengthScore = password.length >= 12 ? 2 : password.length >= 8 ? 1 : 0;
      final score = lengthScore +
          (hasUppercase ? 1 : 0) +
          (hasLowercase ? 1 : 0) +
          (hasNumber ? 1 : 0) +
          (hasSymbol ? 1 : 0);

      String strength = '';
      double barWidth = 0.0;
      Color barColor = Colors.red;

      if (score <= 2) {
        strength = 'Very Weak';
        barWidth = 0.2;
        barColor = const Color(0xFFFF4D4D);
      } else if (score == 3) {
        strength = 'Weak';
        barWidth = 0.4;
        barColor = const Color(0xFFFF8C00);
      } else if (score == 4) {
        strength = 'Medium';
        barWidth = 0.6;
        barColor = const Color(0xFFFFD700);
      } else if (score == 5) {
        strength = 'Strong';
        barWidth = 0.8;
        barColor = const Color(0xFF32CD32);
      } else if (score >= 6) {
        strength = 'Very Strong';
        barWidth = 1.0;
        barColor = const Color(0xFF008000);
      }

      passwordStrength = {
        'strength': strength,
        'barWidth': barWidth,
        'barColor': barColor,
        'checks': {
          'hasLength': hasLength,
          'hasUppercase': hasUppercase,
          'hasLowercase': hasLowercase,
          'hasNumber': hasNumber,
          'hasSymbol': hasSymbol,
        },
      };
    });
  }

  void _resetPasswordStrength() {
    passwordStrength = {
      'strength': '',
      'barWidth': 0.0,
      'barColor': Colors.transparent,
      'checks': {
        'hasLength': false,
        'hasUppercase': false,
        'hasLowercase': false,
        'hasNumber': false,
        'hasSymbol': false,
      },
    };
  }

  Future<void> _handleChangePassword() async {
    if (submitting) return;
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      _showError('Please log in to change password.', onConfirm: () {
        Navigator.pushNamed(context, '/login');
      });
      return;
    }

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError('Please fill in all password fields.');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('New passwords do not match.');
      return;
    }

    final checks = passwordStrength['checks'] as Map<String, bool>;
    if (!checks.values.every((v) => v)) {
      _showError('Password must be 8+ chars with uppercase, lowercase, number, and symbol.');
      return;
    }

    if (!mounted) return;
    setState(() => submitting = true);
    try {
      final credential = firebase_auth.EmailAuthProvider.credential(
          email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      await _db.child('users').child(user.uid).update({
        'lastPasswordChange': DateTime.now().toIso8601String(),
        'password_needs_reset': false,
      });

      if (!mounted) return;
      _showSuccess(
        'Password updated successfully. Sign out?',
        confirmText: 'Sign Out',
        onConfirm: () => _handleLogout(),
        showCancel: true,
      );

      setState(() {
        currentPassword = newPassword = confirmPassword = '';
        showPasswordStrength = false;
        passwordNeedsReset = false;
        isNavigationBlocked = false;
      });
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = 'Failed to change password.';
      if (e.code == 'wrong-password') msg = 'Incorrect current password.';
      if (e.code == 'requires-recent-login') {
        msg = 'Please log in again to change password.';
      }
      _showError(msg);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      setState(() => submitting = false);
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);
    try {
      await authProvider.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
      _showSnackBar('Logged out successfully!', backgroundColor: Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to log out: $e');
    }
  }

  Future<void> _handleAgreeTerms() async {
    if (!agreedTerms) {
      if (!mounted) return;
      _showError('You must agree to the Terms and Conditions.');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      _showError('Not logged in.', onConfirm: () => _auth.signOut());
      return;
    }

    try {
      await _db.child('users').child(user.uid).update({
        'terms_agreed_version': currentTermsVersion,
        'terms_agreed_at': DateTime.now().toIso8601String(),
        'isFirstLogin': false,
        'termsAccepted': true,
      });

      if (!mounted) return;
      setState(() {
        termsModalVisible = false;
        isNavigationBlocked = false;
      });

      if (!mounted) return;
      _showSnackBar('Terms accepted successfully!', backgroundColor: Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save agreement.');
    }
  }

  Future<void> _handleImagePick() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      _showError('Please log in to upload a picture.', onConfirm: () => _auth.signOut());
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (picked == null) return;

      if (!mounted) return;
      setState(() => uploadingImage = true);
      final file = File(picked.path);
      final ref = _storage.ref('profile_pictures/${user.uid}/${const Uuid().v4()}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _db.child('users').child(user.uid).update({
        'profilePicture': url,
        'lastProfilePictureUpdate': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() => _profileData['profilePicture'] = url);

      _showSnackBar('Profile picture uploaded!', backgroundColor: Colors.green);
    } catch (e) {
      _showError('Upload failed: ${e.toString()}');
    } finally {
      setState(() => uploadingImage = false);
    }
  }

  void _showError(String message, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message,
      {String confirmText = 'OK', VoidCallback? onConfirm, bool showCancel = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm?.call();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

 @override
Widget build(BuildContext context) {
  if (_loading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  final user = _auth.currentUser;
  if (user == null) {
    return const Scaffold(
      body: Center(child: Text('Please log in.')),
    );
  }

  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomRight,
          colors: [Color(0x6614AEBB), Color(0xFFFFF9F0)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Profile',
                      style: GlobalStyles.header,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: ThemeConstants.accent,
                      size: 26,
                    ),
                    onPressed: _handleLogout,
                    tooltip: 'Log out',
                  ),
                ],
              ),
            ),

            // Terms modal overlay
            if (termsModalVisible) ..._buildTermsModal(),

            // Main scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      (_profileData['role'] ?? '').contains('AB ADMIN')
                          ? 'Admin Account'
                          : 'Volunteer Group: ${_profileData['organization'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: (_profileData['role'] ?? '').contains('AB ADMIN') ? 22 : 20,
                        color: ThemeConstants.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Profile info
                    if (!termsModalVisible && !passwordNeedsReset) ...[
                      _buildProfilePicture(_profileData['profilePicture']),
                      const SizedBox(height: 30),
                      ..._buildInfoRows(_profileData['hq']),
                    ],

                    // Password change section
                    const SizedBox(height: 20),
                    if (!termsModalVisible || passwordNeedsReset) ...[
                      const Text('Change Password',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildPasswordField(
                          'Current Password', currentPassword, showCurrentPassword,
                          (v) => setState(() => currentPassword = v),
                          (v) => setState(() => showCurrentPassword = v)),
                      _buildPasswordField(
                          'New Password', newPassword, showNewPassword, _handlePasswordInput,
                          (v) => setState(() => showNewPassword = v)),
                      _buildPasswordField(
                          'Confirm Password', confirmPassword, showConfirmPassword,
                          (v) => setState(() => confirmPassword = v),
                          (v) => setState(() => showConfirmPassword = v)),
                      if (showPasswordStrength) _buildStrengthMeter(),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: submitting ? null : _handleChangePassword,
                        child: submitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Change Password'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildProfilePicture(String? url) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
          child: url == null || url.isEmpty
              ? const Icon(Icons.person, size: 50, color: Colors.grey)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: IconButton(
            icon: uploadingImage
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Icon(Icons.camera_alt, color: ThemeConstants.accentBlue),
            onPressed: uploadingImage ? null : _handleImagePick,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInfoRows(String hq) {
  final role = (_profileData['role'] as String?) ?? 'N/A';

  final List<Map<String, dynamic>> rows = [
    {'label': 'Role', 'value': role, 'show': true},
    {
      'label': 'Organization Name',
      'value': (_profileData['organization'] as String?) ?? 'N/A',
      'show': role.contains('ABVN') && (_profileData['organization'] as String?) != 'N/A',
    },
    {
      'label': 'HQ',
      'value': hq,
      'show': role.contains('ABVN') && hq != 'N/A',
    },
    {
      'label': 'Full Name',
      'value': (_profileData['contactPerson'] as String?) ?? 'Unknown',
      'show': true,
    },
    {
      'label': 'Email Address',
      'value': (_profileData['email'] as String?) ?? _auth.currentUser?.email ?? 'N/A',
      'show': true,
    },
    {
      'label': 'Mobile Number',
      'value': (_profileData['mobile'] as String?) ?? 'N/A',
      'show': true,
    },
  ];

  return rows
      .where((row) => row['show'] == true)
      .map((row) => _buildInfoRow(
            row['label'] as String,
            row['value'] as String,
          ))
      .toList();
}

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: ProfileStyles.label)),
          Expanded(child: Text(value, style: ProfileStyles.output)),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
      String hint, String value, bool visible, Function(String) onChanged, Function(bool) onToggle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF605D67)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          TextField(
            obscureText: !visible,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: ThemeConstants.placeholder, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              filled: true,
              fillColor: Colors.transparent,
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            right: 5,
            child: IconButton(
              icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => onToggle(!visible),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthMeter() {
    final checks = passwordStrength['checks'] as Map<String, bool>;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Password Strength: ${passwordStrength['strength']}',
              style: ProfileStyles.strengthText),
          const SizedBox(height: 5),
          Container(
            height: 6,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              widthFactor: passwordStrength['barWidth'],
              child: Container(
                  decoration: BoxDecoration(
                      color: passwordStrength['barColor'], borderRadius: BorderRadius.circular(3))),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...[
                ['At least 8 characters', checks['hasLength'] ?? false],
                ['An uppercase letter', checks['hasUppercase'] ?? false],
                ['A lowercase letter', checks['hasLowercase'] ?? false],
                ['A number', checks['hasNumber'] ?? false],
                ['A symbol (!@#\$ etc.)', checks['hasSymbol'] ?? false],
              ].map((e) {
                final label = e[0] as String;
                final isValid = e[1] as bool;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        isValid ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: isValid ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isValid ? Colors.green : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          )
        ],
      ),
    );
  }

  List<Widget> _buildTermsModal() {
  return [
    Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Terms and Conditions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Introduction',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Welcome to Bayanihan! These Terms and Conditions ("Terms") govern your use of the Bayanihan application and services. By accessing or using Bayanihan, you agree to be bound by these Terms.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '2. User Responsibilities',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• You must provide accurate and complete information during registration and keep it updated.\n'
                        '• You are responsible for maintaining the confidentiality of your account password.\n'
                        '• You agree to use Bayanihan only for lawful purposes and in accordance with these Terms.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '3. Data Collection and Privacy',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'By using Bayanihan, you consent to the collection and storage of your data for disaster response and related purposes as outlined in our Privacy Policy. Our Privacy Policy is an integral part of these Terms and Conditions. We commit to protecting your data and using it responsibly.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '4. Prohibited Activities',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You agree not to engage in any of the following prohibited activities:\n'
                        '• Violating any applicable laws or regulations.\n'
                        '• Transmitting any harmful or malicious code.\n'
                        '• Interfering with the operation of Bayanihan.\n'
                        '• Attempting to gain unauthorized access to our systems.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '5. Intellectual Property',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All content and intellectual property on Bayanihan, including but not limited to text, graphics, logos, and software, are the property of Bayanihan or its licensors and are protected by intellectual property laws.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '6. Disclaimer of Warranties',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bayanihan is provided "as is" and "as available" without any warranties of any kind, either express or implied. We do not warrant that the service will be uninterrupted, error-free, or secure.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '7. Limitation of Liability',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'To the fullest extent permitted by applicable law, Bayanihan shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses, resulting from (a) your access to or use of or inability to access or use the service; (b) any conduct or content of any third party on the service; (c) any content obtained from the service; and (d) unauthorized access, use or alteration of your transmissions or content.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '8. Governing Law',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'These Terms shall be governed and construed in accordance with the laws of the Philippines, without regard to its conflict of law provisions.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '9. Changes to Terms',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days\' notice prior to any new terms taking effect. By continuing to access or use our Service after those revisions become effective, you agree to be bound by the revised terms.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '10. Contact Us',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If you have any questions about these Terms, please contact us at support@bayanihan.com.',
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: agreedTerms,
                          onChanged: (v) => setState(() => agreedTerms = v!),
                        ),
                        const Expanded(
                          child: Text(
                            'I have read and agree to the Terms and Conditions and Privacy Policy.',
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: agreedTerms ? _handleAgreeTerms : null,
                      child: const Text('Agree and Continue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ];
}
}