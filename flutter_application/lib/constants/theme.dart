import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeConstants {
  static const Color primary = Color(0xFF14AEBB);
  static const Color table = Color(0xFF14AEBB);  // Matches primary (lowercase hex)
  static const Color accent = Color(0xFFFA3B99);
  static const Color lightBg = Color(0xFFFFF9F0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF121212);
  static const Color lightBlack = Color(0xFF333333);  // #333 → #333333
  static const Color buttonHover = Color(0xFF0E7781);
  static const Color blue = Color(0xFF4059A5);
  static const Color blueHover = Color(0xFF32488A);
  static const Color red = Color(0xFFD32F2F);
  static const Color redHover = Color(0xFFD63128);
  static const Color green = Color(0xFF34C759);
  static const Color greenHover = Color(0xFF008000);
  static const Color lightBlue = Color(0xFFE8F0FE);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color neonPrimary = Color(0xFF00BCD4);
  static const Color placeholder = Color(0xFF777777);  //

  // Text Styles (using Poppins)
  static TextStyle poppinsBold(double size, {Color? color}) => GoogleFonts.poppins(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color ?? black,
  );

  static TextStyle poppinsMedium(double size, {Color? color}) => GoogleFonts.poppins(
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: color ?? black,
  );

  static TextStyle poppinsRegular(double size, {Color? color}) => GoogleFonts.poppins(
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color ?? black,
  );

}