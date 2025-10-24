import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';

class GlobalStyles {
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
  static final TextStyle header = GoogleFonts.poppins(
    fontWeight: FontWeight.bold,
    fontSize: 20,
    color: ThemeConstants.primary,
  );

}