import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/auth_provider.dart' as myAuth;
import 'nav_screen.dart';

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

  String? _validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email is required.';
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(email)) return 'Please enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? password) {
    if (password == null || password.isEmpty) return 'Password is required.';
    return null; // No length restriction
  }

  // Check if user exists in Realtime DB (users node)
  Future<Map<String, dynamic>?> _getUserFromDB(String email) async {
    try {
      final snapshot = await _database
          .child('users')
          .orderByChild('email')
          .equalTo(email.toLowerCase())
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final entry = data.entries.first;
        final uid = entry.key.toString();
        final userData = entry.value as Map<dynamic, dynamic>;

        return {
          'uid': uid,
          'userData': Map<String, dynamic>.from(userData),
        };
      }
      return null;
    } catch (e) {
      debugPrint('DB check error: $e');
      return null;
    }
  }

  Future<void> _handleLogin(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate inputs
    final emailError = _validateEmail(email);
    final passwordError = _validatePassword(password);

    if (emailError != null || passwordError != null) {
      if (mounted) {
        setState(() {
          _emailError = emailError;
          _passwordError = passwordError;
        });
      }
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      }

      // Step 1: Try Firebase Auth login
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'unknown', message: 'Login failed');
      }

      // Step 2: Confirm user exists in Realtime DB
      final dbUser = await _getUserFromDB(email);
      if (dbUser == null) {
        await _auth.signOut();
        Fluttertoast.showToast(msg: 'Account not fully registered. Please sign up again.');
        return;
      }

      final userData = dbUser['userData'] as Map<String, dynamic>;

      // Optional: Update last login timestamp
      await _database.child('users/${user.uid}/lastLogin').set(DateTime.now().millisecondsSinceEpoch);

      // Success: Set global state and navigate
      Provider.of<myAuth.AuthProvider>(context, listen: false).setUser(user, userData);

      Fluttertoast.showToast(msg: 'Login successful!');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NavScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        setState(() => _passwordError = 'Incorrect password');
      } else if (e.code == 'user-not-found') {
        setState(() => _emailError = 'Email not found');
      } else {
        msg = e.message ?? msg;
      }
      Fluttertoast.showToast(msg: msg);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Login failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToOnboarding() => Navigator.pushNamed(context, '/onboarding');
  void _navigateToRecovery() => Navigator.pushNamed(context, '/recovery');

  @override
  Widget build(BuildContext context) {
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
                  onPressed: _navigateToOnboarding,
                ),
                const SizedBox(height: 40),

                // Title
                const Text(
                  'Login',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: ThemeConstants.accent),
                ),
                const SizedBox(height: 40),

                // Email Field
                const Text('Email:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThemeConstants.primary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Enter Email',
                    hintStyle: const TextStyle(color: ThemeConstants.placeholder, fontSize: 13),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      borderSide: BorderSide(color: ThemeConstants.placeholder, width: 1),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      borderSide: BorderSide(color: ThemeConstants.primary, width: 1.5),
                    ),
                    errorText: _emailError,
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() => _emailError = null),
                  validator: _validateEmail,
                ),

                const SizedBox(height: 24),

                // Password Field
                const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThemeConstants.primary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Enter Password',
                    hintStyle: const TextStyle(color: ThemeConstants.placeholder, fontSize: 13),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      borderSide: BorderSide(color: ThemeConstants.placeholder, width: 1),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      borderSide: BorderSide(color: ThemeConstants.primary, width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: ThemeConstants.primary),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    errorText: _passwordError,
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() => _passwordError = null),
                  validator: _validatePassword,
                ),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _navigateToRecovery,
                    child: const Text('Forgot Password?', style: TextStyle(color: ThemeConstants.accent)),
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
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
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
                  style: TextStyle(fontSize: 14, color: ThemeConstants.black),
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