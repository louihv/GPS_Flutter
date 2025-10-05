import 'package:flutter/material.dart';
import 'package:flutter_application/providers/auth_provider.dart';
import 'package:flutter_application/screens/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';  // Mock if needed for tests
// Adjust to your project name
// Your auth provider
// Your login screen

void main() {
  setUpAll(() async {
    // Initialize Firebase for tests (use a test project or mock)
    await Firebase.initializeApp();
  });

  testWidgets('LoginScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    // Verify title is displayed
    expect(find.text('Login'), findsOneWidget);

    // Verify email field exists
    expect(find.text('Email:'), findsOneWidget);
    expect(find.byType(TextFormField).at(0), findsOneWidget);  // First field is email

    // Verify password field exists
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextFormField).at(1), findsOneWidget);  // Second field is password

    // Verify login button exists
    expect(find.text('Log in'), findsOneWidget);

    // Verify terms text
    expect(find.text('By continuing, you agree to the Terms and Conditions and Privacy Policy.'), findsOneWidget);
  });

  testWidgets('LoginScreen shows email error on invalid input', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    // Tap email field and submit empty form (triggers validation)
    await tester.tap(find.byType(TextFormField).at(0));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Should show error
    expect(find.text('Email is required.'), findsOneWidget);
  });
}