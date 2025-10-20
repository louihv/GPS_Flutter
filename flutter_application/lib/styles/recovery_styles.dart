import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';

class RecoveryStyles {
  // Container background color
  static const Color containerBackground = Color(0xFFFFF7EC); // Matches #FFF7EC

  // Back button style
  static const Icon backButtonIcon = Icon(
    Icons.arrow_back,
    size: 28,
    color: Color(0xFF14AFBC),
  );

  // Title text style
  static TextStyle titleStyle = GoogleFonts.poppins(
    fontSize: 26,
    color: const Color(0xFF14AFBC),
    fontWeight: FontWeight.w500, // Poppins_Medium
  );

  // Description text style (descSecondary and description)
  static TextStyle descriptionStyle = GoogleFonts.poppins(
    fontSize: 16,
    color: const Color(0xFF444444),
    fontWeight: FontWeight.w400, // Poppins_Regular
  );

  // Success description style (slightly smaller for success stage)
  static TextStyle successDescriptionStyle = GoogleFonts.poppins(
    fontSize: 14,
    color: const Color(0xFF444444),
    fontWeight: FontWeight.w400, // Poppins_Regular
  );

  // Label text style
  static TextStyle labelStyle = GoogleFonts.poppins(
    fontSize: 14,
    color: ThemeConstants.accent, // Matches #14AFBC
    fontWeight: FontWeight.w700, // Poppins_Bold
  );

  // Input field decoration
  static InputDecoration inputDecoration = InputDecoration(
    hintText: 'Enter email',
    hintStyle: TextStyle(color: ThemeConstants.placeholder),
    filled: true,
    fillColor: ThemeConstants.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0x3D565252)), // rgba(86, 82, 82, 0.24)
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0x3D565252)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
  );

  // Input text style
  static TextStyle inputTextStyle = GoogleFonts.poppins(
    fontSize: 15,
    color: ThemeConstants.lightBlack,
    fontWeight: FontWeight.w400, // Poppins_Regular
  );

  // Button style
  static ButtonStyle buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF14AFBC),
    padding: const EdgeInsets.symmetric(vertical: 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 1,
    shadowColor: ThemeConstants.black.withOpacity(0.3),
  );

  // Button text style
  static TextStyle buttonTextStyle = GoogleFonts.poppins(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.w600, // Poppins_SemiBold
  );

  // Success icon
  static const Icon successIcon = Icon(
    Icons.check_circle,
    size: 130,
    color: Color(0xFF14AFBC),
  );
}