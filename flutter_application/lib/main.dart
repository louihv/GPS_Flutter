import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/constants/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; 
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';  
import 'screens/dashboard_screen.dart';  
import 'screens/onboarding_screen.dart'; 
import 'screens/recovery_screen.dart';  


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MyApp(),
    ),
  );
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
          shadowColor: ThemeConstants.buttonHover.withValues(alpha:0.1), 
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    hintStyle: TextStyle(color: ThemeConstants.placeholder),
    filled: true,
    fillColor: ThemeConstants.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: ThemeConstants.lightBlack.withValues(alpha: 0.29)
),
    ),
    
  ),
),
      initialRoute: '/login', 
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),  
        '/dashboard': (context) => DashboardScreen(),  
        '/onboarding': (context) => OnboardingScreen(),  
        '/recovery': (context) => RecoveryScreen(),  
      },
     onGenerateRoute: (settings) {
        return null;  
      },
    );
  }
}