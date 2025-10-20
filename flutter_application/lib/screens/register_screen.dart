import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as myAuth;
import '../constants/theme.dart';
import '../styles/register_styles.dart'; 

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _organizationController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _organizationError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  // Validators (pure functions, return String? - no setState)
  String? _validateFirstName(String? value) {
    if (value == null || value.isEmpty) return 'First name is required.';
    if (value.length < 2) return 'First name must be at least 2 characters.';
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.isEmpty) return 'Last name is required.';
    if (value.length < 2) return 'Last name must be at least 2 characters.';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required.';
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(value)) return 'Please enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters long.';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final password = _passwordController.text;
    if (value != password) return 'Passwords do not match.';
    return _validatePassword(value);  // Also validate length
  }

  String? _validateOrganization(String? value) {
    if (value == null || value.isEmpty) return 'Organization is required.';
    return null;
  }

  Future<bool> _emailExists(String email) async {
    try {
      final emailLower = email.toLowerCase();
      final emailRef = _database.child('users/emailIndex/$emailLower');
      final snapshot = await emailRef.get();
      return snapshot.exists && snapshot.value != null;
    } catch (e) {
      debugPrint('Error checking email: $e');
      return false;
    }
  }

  Future<void> _handleRegister(BuildContext context) async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final organization = _organizationController.text.trim();

    final firstNameError = _validateFirstName(firstName);
    final lastNameError = _validateLastName(lastName);
    final emailError = _validateEmail(email);
    final passwordError = _validatePassword(password);
    final confirmError = _validateConfirmPassword(confirmPassword);
    final orgError = _validateOrganization(organization);

    if (firstNameError != null || lastNameError != null || emailError != null || passwordError != null || confirmError != null || orgError != null) {
      if (mounted) {
        setState(() {
          _firstNameError = firstNameError;
          _lastNameError = lastNameError;
          _emailError = emailError;
          _passwordError = passwordError;
          _confirmPasswordError = confirmError;
          _organizationError = orgError;
        });
      }
      return;
    }

    if (_isLoading) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      // Check if email exists
      final emailTaken = await _emailExists(email);
      if (emailTaken) {
        if (mounted) setState(() => _emailError = 'Email already in use.');
        Fluttertoast.showToast(msg: 'Email already registered. Please log in.');
        return;
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user == null) throw FirebaseAuthException(code: 'unknown');

      final now = DateTime.now().millisecondsSinceEpoch;
      final userData = {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'organization': organization,
        'role': 'ABVN', 
        'emailVerified': false,
        'isFirstLogin': true,
        'lastVerificationEmailSent': now,
        'contactPerson': '',  
      };

      await _database.child('users/${user.uid}').set(userData);
      await _database.child('users/emailIndex/$email').set(user.uid);

      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://www.angat-bayanihan.com/pages/login.html',
          handleCodeInApp: true,
        );
        await user.sendEmailVerification(actionCodeSettings);
        await _database.child('users/${user.uid}/lastVerificationEmailSent').set(now);
        Fluttertoast.showToast(msg: 'Verification email sent. Check inbox (spam/junk).');
      } catch (verificationError) {
        debugPrint('Error sending verification: ${verificationError.toString()}');
        if (verificationError is FirebaseAuthException && verificationError.code == 'too-many-requests') {
          Fluttertoast.showToast(msg: 'Too many requests. Try again later.');
        } else {
          Fluttertoast.showToast(msg: 'Verification failed: ${verificationError.toString()}. Please log in to resend.');
        }
      }

      // Set global auth state
      Provider.of<myAuth.AuthProvider>(context, listen: false).setUser(user, userData);

      Fluttertoast.showToast(msg: 'Registration successful. Please verify your email.');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');  // Or '/onboarding'
    } on FirebaseAuthException catch (authError) {
      debugPrint('Auth error: ${authError.code} - ${authError.message}');
      String errorMsg = 'Registration failed.';
      switch (authError.code) {
        case 'email-already-in-use':
          if (mounted) setState(() => _emailError = 'Email already in use.');
          break;
        case 'weak-password':
          if (mounted) setState(() => _passwordError = 'Password is too weak.');
          break;
        case 'invalid-email':
          if (mounted) setState(() => _emailError = 'Invalid email format.');
          break;
        default:
          errorMsg = authError.message ?? authError.toString();
      }
      Fluttertoast.showToast(msg: errorMsg);
    } catch (e) {
      debugPrint('General register error: $e');
      Fluttertoast.showToast(msg: 'Registration failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToOnboarding(BuildContext context) {
    Navigator.pushNamed(context, '/onboarding');
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/login');
  }

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
                  onPressed: () => _navigateToOnboarding(context),
                ),
                const SizedBox(height: 40),
                // Title
                const Text(
                  'Register',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ThemeConstants.accent),
                ),
                const SizedBox(height: 40),
                // Form Container
                SizedBox(
                  width: RegisterStyles.formWidth,  // Fixed: Static class access
                  height: RegisterStyles.formHeight,  // Fixed: Static class access
                  child: Container(
                    alignment: Alignment.center,
                    decoration: RegisterStyles.formContainerDecoration(context),  // Fixed: Static class access
                    padding: RegisterStyles.contentPadding,  // Fixed: Static class access
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // First Name
                        Text('First Name', style: RegisterStyles.nameLabelStyle),  // Fixed: Static class access
                        const SizedBox(height: 5),
                        SizedBox(
                          width: RegisterStyles.inputWidth,  // Fixed: Static class access
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: RegisterStyles.inputDecoration(  // Fixed: Static class access
                              hintText: 'Enter First Name',
                              errorText: _firstNameError,
                            ),
                            onChanged: (value) => _clearError(() => _firstNameError),
                            validator: _validateFirstName,
                          ),
                        ),
                        const SizedBox(height: RegisterStyles.inputMarginBottom),  // Fixed: Static class access
                        // Last Name
                        Text('Last Name', style: RegisterStyles.nameLabelStyle),  // Fixed: Static class access
                        const SizedBox(height: 5),
                        SizedBox(
                          width: RegisterStyles.inputWidth,  // Fixed: Static class access
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: RegisterStyles.inputDecoration(  // Fixed: Static class access
                              hintText: 'Enter Last Name',
                              errorText: _lastNameError,
                            ),
                            onChanged: (value) => _clearError(() => _lastNameError),
                            validator: _validateLastName,
                          ),
                        ),
                        const SizedBox(height: RegisterStyles.inputMarginBottom),  // Fixed: Static class access
                        // Email
                        Text('Email', style: RegisterStyles.labelStyle),  // Fixed: Static class access
                        const SizedBox(height: 5),
                        SizedBox(
                          width: RegisterStyles.inputWidth,  // Fixed: Static class access
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textCapitalization: TextCapitalization.none,
                            decoration: RegisterStyles.inputDecoration(  // Fixed: Static class access
                              hintText: 'Enter Email',
                              errorText: _emailError,
                            ),
                            onChanged: (value) => _clearError(() => _emailError),
                            validator: _validateEmail,
                          ),
                        ),
                        const SizedBox(height: RegisterStyles.inputMarginBottom),  // Fixed: Static class access
                        // Organization
                        Text('Organization', style: RegisterStyles.orgLabelStyle),  // Fixed: Static class access
                        const SizedBox(height: 5),
                        SizedBox(
                          width: RegisterStyles.inputWidth,  // Fixed: Static class access
                          child: TextFormField(
                            controller: _organizationController,
                            decoration: RegisterStyles.inputDecoration(  // Fixed: Static class access
                              hintText: 'Enter Organization',
                              errorText: _organizationError,
                            ),
                            onChanged: (value) => _clearError(() => _organizationError),
                            validator: _validateOrganization,
                          ),
                        ),
                        const SizedBox(height: RegisterStyles.inputMarginBottom),  // Fixed: Static class access
                        // Password
                        Text('Password', style: RegisterStyles.labelStyle),  // Fixed: Static class access
                        const SizedBox(height: 5),
                        SizedBox(
                          width: RegisterStyles.inputWidth,  // Fixed: Static class access
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            decoration: RegisterStyles.inputDecoration(  // Fixed: Static class access
                              hintText: 'Enter Password',
                              errorText: _passwordError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: ThemeConstants.primary,
                                ),
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                            onChanged: (value) => _clearError(() => _passwordError),
                            validator: _validatePassword,
                          ),
                        ),
                        const SizedBox(height: RegisterStyles.inputMarginBottom),  // Fixed: Static class access
                        // Confirm Password
                        Text('Confirm Password', style: RegisterStyles.labelStyle),  // Fixed: Static class access
                        const SizedBox(height: 5),
                        SizedBox(
                          width: RegisterStyles.inputWidth,  // Fixed: Static class access
                          child: TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: RegisterStyles.confirmPasswordDecoration(errorText: _confirmPasswordError),  // Fixed: Static class access
                            onChanged: (value) => _clearError(() => _confirmPasswordError),
                            validator: _validateConfirmPassword,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Link to Login
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _navigateToLogin(context),
                            child: const Text('Already have an account? Log in', style: TextStyle(color: ThemeConstants.accent)),
                          ),
                        ),
                        const Spacer(),
                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _handleRegister(context),
                            style: _isLoading ? RegisterStyles.disabledButtonStyle(context) : RegisterStyles.primaryButtonStyle(context),  // Fixed: Static class access
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                  )
                                : Text('Register', style: RegisterStyles.buttonTextStyle),  // Fixed: Static class access
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // Terms Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'By registering, you agree to the Terms and Conditions and Privacy Policy.',
                    style: RegisterStyles.termsTextStyle,  // Fixed: Static class access
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearError(VoidCallback setter) {
    setter();
    if (mounted) setState(() {});  
  }
}