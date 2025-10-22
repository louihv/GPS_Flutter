import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_application/providers/auth_provider.dart' as myAuth;
import 'package:flutter/material.dart';
import 'package:flutter_application/screens/nav_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); 

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Updated: Returns String? (error message or null) - no setState()
  String? _validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required.';
    }
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;  // No error
  }

  // Updated: Returns String? (error message or null) - no setState()
  String? _validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    return null;  // No error
  }

Future<Map<String, dynamic>?> _checkEmailExists(String email) async {
  try {
    final emailLower = email.toLowerCase();
    debugPrint('Querying DB for email: $emailLower');
    final snapshot = await _database
        .child('users')
        .orderByChild('email')
        .equalTo(emailLower)
        .get();

    debugPrint('Snapshot exists: ${snapshot.exists}, value: ${snapshot.value}');  

    if (snapshot.exists && snapshot.value != null) {
      final value = snapshot.value as Map<dynamic, dynamic>;
      debugPrint('Value type: ${value.runtimeType}, entries: ${value.length}'); 
      if (value.isNotEmpty) {
        final userEntry = value.entries.first;
        final uid = userEntry.key.toString();
        final userDataRaw = userEntry.value as Map<dynamic, dynamic>;
        final userData = <String, dynamic>{
          'uid': uid,
          'email': userDataRaw['email'] ?? '',
          'role': userDataRaw['role'] ?? '',
          'emailVerified': userDataRaw['emailVerified'] ?? false,
          'isFirstLogin': userDataRaw['isFirstLogin'] ?? true,
          'lastVerificationEmailSent': userDataRaw['lastVerificationEmailSent'] ?? 0,
          ...Map<String, dynamic>.from(userDataRaw),
        };
        debugPrint('Found user: UID=$uid, Role=${userData['role']}, EmailVerified=${userData['emailVerified']}');
        return {'uid': uid, 'userData': userData};
      } else {
        debugPrint('Value is empty map');
      }
    } else {
      debugPrint('Snapshot value is null or doesn\'t exist');
    }

    debugPrint('No user found for email: $emailLower');
    return null;
  } catch (error) {
    debugPrint('Error checking email: $error');
    return null;
  }
}

Future<void> _handleLogin(BuildContext context) async {
  final email = _emailController.text.trim();
  final password = _passwordController.text;

  // Manual validation before proceeding (outside build)
  final emailError = _validateEmail(email);
  final passwordError = _validatePassword(password);
  if (emailError != null) {
    if (mounted) setState(() => _emailError = emailError);
    return;
  }
  if (passwordError != null) {
    if (mounted) setState(() => _passwordError = passwordError);
    return;
  }

  if (_isLoading) return;

  setState(() => _isLoading = true);

  try {
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }

    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;

    if (user == null) throw FirebaseAuthException(code: 'unknown');

    final userInfo = await _checkEmailExists(email);
    if (userInfo == null) {
      Fluttertoast.showToast(msg: 'User account not fully set up. Please register again.');
      await _auth.signOut();
      _navigateToLogin(context);
      return;
    }

    final userData = userInfo['userData'] as Map<String, dynamic>?;
    final isAdmin = userData?['role'] == 'AB ADMIN';

    if (!isAdmin && !user.emailVerified) {
      final lastVerificationSent = userData?['lastVerificationEmailSent'] ?? 0;
      final oneHour = 60 * 60 * 1000;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastVerificationSent < oneHour) {
        Fluttertoast.showToast(msg: 'Verification email sent. Check inbox (and spam/junk).');
        await _auth.signOut();
        _navigateToLogin(context);
        return;
      }

      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://www.angat-bayanihan.com/pages/login.html',
          handleCodeInApp: true,
        );
        await user.sendEmailVerification(actionCodeSettings);
        await _database.child('users/${user.uid}/lastVerificationEmailSent').set(now);
        Fluttertoast.showToast(msg: 'Verification email sent. Check inbox (spam/junk).');
        await _auth.signOut();
        _navigateToLogin(context);
        return;
      } catch (verificationError) {
        debugPrint('Error sending verification: ${verificationError.toString()}');
        if (verificationError is FirebaseAuthException &&
            verificationError.code == 'too-many-requests') {
          Fluttertoast.showToast(msg: 'Too many requests. Try again later.');
        } else {
          Fluttertoast.showToast(msg: 'Verification failed: ${verificationError.toString()}');
        }
        await _auth.signOut();
        _navigateToLogin(context);
        return;
      }
    }

    // Update DB if email verified but flag not set
    if (user.emailVerified && !(userData?['emailVerified'] ?? false)) {
      await _database.child('users/${user.uid}/emailVerified').set(true);
      if (userData?['isFirstLogin'] == true) {
        await _database.child('users/${user.uid}/isFirstLogin').set(false);
      }
      Fluttertoast.showToast(msg: 'Email verified successfully!');
    }

    if (userData?['isFirstLogin'] == true) {
      await _database.child('users/${user.uid}/isFirstLogin').set(false);
    }

    // Set global auth state
    Provider.of<myAuth.AuthProvider>(context, listen: false).setUser(user, userData);

    Fluttertoast.showToast(msg: 'Login successful.');
    // Navigate to home
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavScreen()),
      );   
       }
  } on FirebaseAuthException catch (authError) {
    debugPrint('Auth error: ${authError.code} - ${authError.message}');
    if (authError.code == 'wrong-password' || authError.code == 'invalid-credential') {
      if (mounted) setState(() => _passwordError = 'Password incorrect');
    } else if (authError.code == 'user-not-found') {
      if (mounted) setState(() => _emailError = 'Email not found.');
    } else {
      Fluttertoast.showToast(msg: 'Login failed: ${authError.message ?? authError.toString()}');
    }
  } catch (generalError) {
    debugPrint('General login error: ${generalError.toString()}');
    Fluttertoast.showToast(msg: 'Login failed: ${generalError.toString()}');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}


  void _navigateToLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _navigateToOnboarding(BuildContext context) {
    Navigator.pushNamed(context, '/onboarding');
  }

  void _navigateToRecovery(BuildContext context) {
    Navigator.pushNamed(context, '/recovery');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: ThemeConstants.lightBg, 
      body: SafeArea(
        child: SingleChildScrollView( 
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 26, color: ThemeConstants.primary),  
                  onPressed: () => _navigateToOnboarding(context),
                ),
                const SizedBox(height: 40),
                // Title
                const Text(
                  'Login',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: ThemeConstants.accent), 
                ),
                const SizedBox(height: 40),
                // Email Field
                const Text('Email:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color:ThemeConstants.primary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  autovalidateMode: AutovalidateMode.onUserInteraction,  // Real-time validation
                  decoration: InputDecoration(
                    hintText: 'Enter Email',
                    hintStyle: const TextStyle(color: ThemeConstants.placeholder),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    errorText: _emailError,  // Display manual errors (e.g., from auth)
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                  onChanged: (value) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);  // Clear on typing
                    }
                  },
                  onTap: () {
                    if (_emailError != null) {
                      setState(() => _emailError = null);  // Clear on tap
                    }
                  },
                  validator: _validateEmail,  // Pure function - returns String? or null
                ),
                if (_emailError != null) const SizedBox(height: 4),
                // Password Field
                const SizedBox(height: 24),
                const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color:ThemeConstants.primary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,  // Real-time validation
                  decoration: InputDecoration(
                    hintText: 'Enter Password',
                    hintStyle: const TextStyle(color: ThemeConstants.placeholder),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: ThemeConstants.primary,),
                      onPressed: () => setState(() => _showPassword = !_showPassword),  // Safe post-build
                    ),
                    errorText: _passwordError,  // Display manual errors (e.g., from auth)
                    errorStyle: const TextStyle(color: ThemeConstants.red),
                  ),
                  onChanged: (value) {
                    // Clear error on typing (real-time)
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  onTap: () {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  validator: _validatePassword,  // Pure function - returns String? or null
                ),
                if (_passwordError != null) const SizedBox(height: 4),
                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : () => _navigateToRecovery(context),
                    child: const Text('Forgot Password', style: TextStyle(color: ThemeConstants.accent)),
                  ),
                ),
                const SizedBox(height: 40),
                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleLogin(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConstants.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Log in', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 20),
                // Terms Text
                const Text(
                  'By continuing, you agree to the Terms and Conditions and Privacy Policy.',
                  style: TextStyle(fontSize: 14, color:ThemeConstants.black),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}