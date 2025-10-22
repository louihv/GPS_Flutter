import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';

class DashboardStyles {
  // Spacing and Border Radius (from RN)
  static const double xsmall = 5;
  static const double small = 10;
  static const double medium = 15;
  static const double large = 20;
  static const double xlarge = 30;
  static const double smallRadius = 4;
  static const double mediumRadius = 8;
  static const double largeRadius = 10;
  static const double xlargeRadius = 20;

  // Shadows (common for cards/icons)
  static const BoxShadow cardShadow = BoxShadow(
    color: Colors.black26,  // shadowOpacity 0.3
    offset: Offset(0, 5),  // shadowOffset
    blurRadius: 5,  // shadowRadius
  );

  static const BoxShadow iconShadow = BoxShadow(
    color: Colors.black26,
    offset: Offset(0, 5),
    blurRadius: 5,
  );

  // Inner Shadows (simulated with gradients/positioned containers)
  static BoxDecoration innerTopShadow() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white.withOpacity(0.3), Colors.transparent],
      stops: [0.0, 0.5],
    ),
  );

  static BoxDecoration innerBottomShadow() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Colors.transparent, Colors.white.withOpacity(0.3)],
      stops: [0.0, 0.5],
    ),
  );

  // Gradient Container
  static BoxDecoration gradientContainer() => const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color.fromRGBO(255, 201, 229, 0.416), ThemeConstants.lightBg], 
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    ),
  );

  // Metrics Card
  static BoxDecoration formCard(BuildContext context) => BoxDecoration(
    borderRadius: BorderRadius.circular(largeRadius),
    border: Border.all(color: ThemeConstants.primary, width: 1),
    boxShadow: [cardShadow],
    gradient: LinearGradient(
      colors: [ThemeConstants.primary.withOpacity(0.1), ThemeConstants.primary.withOpacity(0.05)],
    ),
  );

  // Metric Gradient Card
  static BoxDecoration metricGradientCard() => BoxDecoration(
    borderRadius: BorderRadius.circular(largeRadius),
    color: const Color(0xFF1F1F1F).withOpacity(0.16),
  );

  // Metric Card (row layout)
  static EdgeInsets metricCardPadding() => const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );

  // Icon Container
  static BoxDecoration iconContainer() => BoxDecoration(
    color: ThemeConstants.lightBlue,
    shape: BoxShape.circle,
    boxShadow: [iconShadow],
  );

  // Text Styles (Poppins)
  static TextStyle sectionTitleStyle = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: ThemeConstants.accent,
  );

  static TextStyle metricLabelStyle = GoogleFonts.poppins(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ThemeConstants.white, 
  );

  static TextStyle metricValueStyle = GoogleFonts.poppins(
    fontSize: 20,
    color: ThemeConstants.lightBlue,
    fontWeight: FontWeight.w400,
  );

  static TextStyle permissionDeniedHeaderStyle = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: ThemeConstants.black,
  );

  static TextStyle permissionDeniedTextStyle = GoogleFonts.poppins(
    fontSize: 14,
    color: ThemeConstants.lightBlack,
    fontWeight: FontWeight.w400,
  );

  static TextStyle buttonTextStyle = GoogleFonts.poppins(
    fontSize: 14,
    color: ThemeConstants.white,
    fontWeight: FontWeight.w400,
  );

  // Modal (bottom sheet)
  static BoxDecoration modalContainer() => BoxDecoration(
    color: ThemeConstants.lightBg,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
    ),
  );

  static BoxDecoration permissionDeniedContainer() => BoxDecoration(
    color: ThemeConstants.white,
    borderRadius: BorderRadius.circular(mediumRadius),
    boxShadow: [cardShadow],
  );

  // Buttons
  static ButtonStyle retryButtonStyle() => ElevatedButton.styleFrom(
    backgroundColor: ThemeConstants.primary,
    foregroundColor: ThemeConstants.white,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
    side: const BorderSide(color: Colors.white, width: 1),
  );

  static ButtonStyle closeButtonStyle() => OutlinedButton.styleFrom(
    foregroundColor: ThemeConstants.primary,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
    side: BorderSide(color: ThemeConstants.primary, width: 1),
  );

  // Header
  static EdgeInsets headerPadding() => const EdgeInsets.symmetric(horizontal: 20);
  static const double headerHeight = 80; 
}