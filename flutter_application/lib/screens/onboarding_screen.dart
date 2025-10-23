import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _imageScaleController;
  late Animation<double> _imageScale;

  @override
  void initState() {
    super.initState();
    _imageScaleController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _imageScale = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(parent: _imageScaleController, curve: Curves.easeOut),
    );
    // Start animation on init (mirrors useEffect)
    _imageScaleController.forward();
  }

  @override
  void dispose() {
    _imageScaleController.dispose();
    super.dispose();
  }

  void _handleScreenPress() {
    Navigator.pushReplacementNamed(context, '/login');
  }

   void _handleGetStarted() {
    Navigator.pushReplacementNamed(context, '/register');
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConstants.lightBg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              ScaleTransition(
                scale: _imageScale,
                child: Image.asset(
                  'assets/images/ab_logo.png',  // Adjust path if needed
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              // Title Text
              Text(
                'Disaster Relief and Rehabilitation Management Portal',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: ThemeConstants.primary,
                  fontWeight: FontWeight.w500,  // Poppins_Medium equivalent
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),  
              // Button
              
              Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: OutlinedButton(
                  onPressed: _handleGetStarted, 
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: ThemeConstants.primary, 
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Get Started",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: ThemeConstants.primary,
                      fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
           const SizedBox(height: 10),
          SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: ElevatedButton(
                    onPressed: _handleScreenPress,
                    style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConstants.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 6,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: Text(
                    "Log In",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: const Color(0xFFFFF9F0),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  ),
                ),
        ],
      ),

              const Spacer(),  // Extra space below button
            ],
          ),
        ),
      ),
    );
  }
}