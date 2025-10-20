import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../styles/recovery_styles.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _emailController = TextEditingController();
  int _passwordRecoveryStage = 1;
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    try {
      bool userFound = false;
      String? userId;

      // Query users by email
      final snapshot = await _database.child('users').orderByChild('email').equalTo(email).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        userFound = true;
        userId = data.keys.first;
      }

      if (!userFound) {
        _showErrorDialog('No account is associated with this email address. Please try again or register.');
        return;
      }

      // FIXED: Removed 'const' from ActionCodeSettings
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://bayanihan-5ce7e.firebaseapp.com/pages/login.html',
        handleCodeInApp: false,
      );
      await _auth.sendPasswordResetEmail(email: email, actionCodeSettings: actionCodeSettings);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: Text(
              'A password reset link has been sent to $email. Please check your email (including spam/junk folder).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it!'),
              ),
            ],
          ),
        );
        setState(() => _passwordRecoveryStage = 2);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send reset email. Please try again.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No account is associated with this email address.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address format.';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('Failed to send reset email. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RecoveryStyles.containerBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back Button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: RecoveryStyles.backButtonIcon,
                  onPressed: () {
                    setState(() => _passwordRecoveryStage = 1);
                    _emailController.clear();
                    Navigator.pop(context);
                  },
                ),
              ),
              // Title
              Text(
                'Forgot Password',
                style: RecoveryStyles.titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Content based on stage
              Expanded(
                child: _passwordRecoveryStage == 1
                    ? _buildInputStage()
                    : _buildSuccessStage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputStage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          'Please enter your registered email address to recover your password.',
          style: RecoveryStyles.descriptionStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Email Address',
            style: RecoveryStyles.labelStyle,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: RecoveryStyles.inputDecoration,
          style: RecoveryStyles.inputTextStyle,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleEmailSubmit,
            style: RecoveryStyles.buttonStyle,
            child: Text(
              'Submit',
              style: RecoveryStyles.buttonTextStyle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RecoveryStyles.successIcon,
        const SizedBox(height: 20),
        Text(
          'Success!',
          style: RecoveryStyles.titleStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          'A password reset link has been sent to your registered email.',
          style: RecoveryStyles.successDescriptionStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _passwordRecoveryStage = 1);
              _emailController.clear();
              Navigator.pop(context);
            },
            style: RecoveryStyles.buttonStyle,
            child: Text(
              'Continue',
              style: RecoveryStyles.buttonTextStyle,
            ),
          ),
        ),
      ],
    );
  }
}