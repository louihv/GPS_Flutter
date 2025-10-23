import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';

class RegisterStyles {
  // Spacing (from RN constants)
  static const double xsmall = 5;
  static const double small = 10;
  static const double medium = 15;
  static const double large = 20;
  static const double xlarge = 30;

  // Shadows (common for cards/icons)
  static const BoxShadow cardShadow = BoxShadow(
    color: Colors.black26,  // Matches shadowOpacity 0.3
    offset: Offset(0, 5),
    blurRadius: 6,
  );

  static const BoxShadow buttonShadow = BoxShadow(
    color: Colors.black12,
    offset: Offset(0, 4),
    blurRadius: 6,
  );

  // Form Container (width 320, height 550 for extra fields, border, shadow)
  static const double formWidth = 320;
  static const double formHeight = 550;  // Taller for register
  static BoxDecoration formContainerDecoration(BuildContext context) => BoxDecoration(
    color: ThemeConstants.white,
    borderRadius: BorderRadius.circular(15),
    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
    boxShadow: [cardShadow],
  );

  // Content Padding
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 10);

  // Input Width and Margin
  static const double inputWidth = 300;
  static const double inputMarginBottom = 15;

  // Input Decoration (generic for all fields)
  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      filled: true,
      fillColor: ThemeConstants.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Color(0xFF565252).withOpacity(0.24), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Color(0xFF565252).withOpacity(0.24), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ThemeConstants.primary, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red, width: 1),
      ),
      errorStyle: const TextStyle(color: Colors.red),
      labelStyle: GoogleFonts.poppins(
      fontSize: 12, 
      fontWeight: FontWeight.w400,
      color: const Color(0xFF121212),
    ),
    );
  }

  // Confirm Password Decoration (no suffix icon)
  static InputDecoration confirmPasswordDecoration({
    String? errorText,
  }) => inputDecoration(
    hintText: 'Confirm Password',
    errorText: errorText,
    suffixIcon: null,
  );

  // Button Styles
  static ButtonStyle primaryButtonStyle(BuildContext context) => ElevatedButton.styleFrom(
    backgroundColor: ThemeConstants.primary,
    foregroundColor: ThemeConstants.white,
    padding: const EdgeInsets.symmetric(vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    elevation: 5,
    shadowColor: Colors.black26,
  );

  static ButtonStyle disabledButtonStyle(BuildContext context) => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFA1D8D9),  // Lighter disabled
    foregroundColor: ThemeConstants.white,
    padding: const EdgeInsets.symmetric(vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    elevation: 2,
  );

  static TextStyle titleStyle = GoogleFonts.poppins(
    fontSize: 26,
    fontWeight: FontWeight.w500,
    color: ThemeConstants.primary,
  );

  static TextStyle welcomeTextStyle = GoogleFonts.poppins(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: ThemeConstants.accent,
  );

  static TextStyle inputStyle = GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: ThemeConstants.black,
  );


  static TextStyle labelStyle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: ThemeConstants.primary,
  );

  static TextStyle textSkills = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Color(0xFF121212),
);


  static TextStyle nameLabelStyle = labelStyle.copyWith(fontSize: 12);  

  static TextStyle orgLabelStyle = labelStyle.copyWith(fontSize: 12);  

  static TextStyle buttonTextStyle = GoogleFonts.poppins(
    fontSize: 16,
    color: ThemeConstants.white,
    fontWeight: FontWeight.w400,
  );

  static TextStyle recoverTextStyle = GoogleFonts.poppins(
    fontSize: 12,
    color: ThemeConstants.accent,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.underline,
  );

  static TextStyle termsTextStyle = GoogleFonts.poppins(
    fontSize: 12,
    color: ThemeConstants.black,
    fontWeight: FontWeight.w400,
    height: 1.57,  
  );
}