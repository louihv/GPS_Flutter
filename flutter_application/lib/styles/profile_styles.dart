import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';

class ProfileStyles {
  // Spacing
  static const double spacingXSmall = 5;
  static const double spacingSmall = 10;
  static const double spacingMedium = 15;
  static const double spacingLarge = 20;
  static const double spacingXLarge = 30;

  // Border Radius
  static const double borderRadiusSmall = 4;
  static const double borderRadiusMedium = 8;
  static const double borderRadiusLarge = 10;
  static const double borderRadiusXLarge = 20;

  // Text Styles with Poppins
  static final TextStyle label = GoogleFonts.poppins(
    fontWeight: FontWeight.bold,
    fontSize: 13,
    color: ThemeConstants.primary,
  );

  static final TextStyle output = GoogleFonts.poppins(
    fontSize: 13,
    color: Colors.black,
  );

  static final TextStyle strengthText = GoogleFonts.poppins(
    fontSize: 14,
    color: ThemeConstants.primary,
    fontWeight: FontWeight.w600,
  );

  // Optional: Reusable variants
  static TextStyle header = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: ThemeConstants.primary,
  );

  static TextStyle subtitle = GoogleFonts.poppins(
    fontSize: 14,
    color: Colors.grey[700],
  );
}