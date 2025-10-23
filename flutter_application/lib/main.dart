import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/constants/theme.dart';
import 'package:flutter_application/screens/profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/recovery_screen.dart';
import 'screens/register_screen.dart';
import 'screens/nav_screen.dart';
import 'screens/communityboard_screen.dart';

import 'screens/org_request_page.dart';
import 'screens/recommendations_page.dart';
import 'screens/map_page.dart';





void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MyApp(),
    ),
  );
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    print('AuthProvider user: ${authProvider.user}'); 
    if (authProvider.user == null) {
      print('Navigating to LoginScreen');
      return const LoginScreen();
    }
    print('Navigating to NavScreen');
    return const NavScreen();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bayanihan App',
      theme: ThemeData(
        primaryColor: ThemeConstants.primary,
        scaffoldBackgroundColor: ThemeConstants.lightBg,
        colorScheme: ColorScheme.fromSeed(seedColor: ThemeConstants.primary),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConstants.primary,
            foregroundColor: ThemeConstants.white,
            shadowColor: ThemeConstants.buttonHover.withOpacity(0.1), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: ThemeConstants.placeholder),
          filled: true,
          fillColor: ThemeConstants.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ThemeConstants.lightBlack.withOpacity(0.29)),
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/recovery': (context) => const RecoveryScreen(),
        '/profile': (context) => const ProfileScreen(), 
        '/communityboard_screen': (context) => const CommunityBoardScreen(),
        '/org_request': (context) => const OrgRequestPage(), // ✅ Added new route
        '/recommendations': (context) => const RecommendationsPage(),
        '/map': (context) => const MapPage(),  // ✅ Add this line



      },
    );
  }
}