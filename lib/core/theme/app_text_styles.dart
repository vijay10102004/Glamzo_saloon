import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Display (Playfair Display — elegant serif matching the image style) ──
  static TextStyle display1 = GoogleFonts.playfairDisplay(
    fontSize: 40, fontWeight: FontWeight.w700,
    color: AppColors.ink, letterSpacing: 0.3, height: 1.1,
  );
  static TextStyle display2 = GoogleFonts.playfairDisplay(
    fontSize: 30, fontWeight: FontWeight.w700,
    color: AppColors.ink, letterSpacing: 0.2, height: 1.15,
  );
  static TextStyle displayItalic = GoogleFonts.playfairDisplay(
    fontSize: 30, fontWeight: FontWeight.w600,
    fontStyle: FontStyle.italic, color: AppColors.ink, height: 1.15,
  );
  static TextStyle heroName = GoogleFonts.playfairDisplay(
    fontSize: 32, fontWeight: FontWeight.w700,
    color: AppColors.ink, letterSpacing: 0.2, height: 1.1,
  );
  static TextStyle heroNameItalic = GoogleFonts.playfairDisplay(
    fontSize: 32, fontWeight: FontWeight.w600,
    fontStyle: FontStyle.italic, color: AppColors.ink, letterSpacing: 0.2, height: 1.1,
  );
  static TextStyle sectionTitle = GoogleFonts.playfairDisplay(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.ink, letterSpacing: 0.2, height: 1.2,
  );
  static TextStyle cardTitle = GoogleFonts.playfairDisplay(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: AppColors.ink, height: 1.2,
  );

  // ── Body (Poppins — clean, professional, matches the image labels) ──
  static TextStyle body1 = GoogleFonts.poppins(
    fontSize: 16, fontWeight: FontWeight.w400,
    color: AppColors.ink, height: 1.5,
  );
  static TextStyle body2 = GoogleFonts.poppins(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.text2, height: 1.5,
  );
  static TextStyle label = GoogleFonts.poppins(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: AppColors.text2, letterSpacing: 0.1,
  );
  static TextStyle eyebrow = GoogleFonts.poppins(
    fontSize: 12, fontWeight: FontWeight.w700,
    color: AppColors.text3, letterSpacing: 2.0,
  );
  static TextStyle caption = GoogleFonts.poppins(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.text4, height: 1.4,
  );
  static TextStyle btnLabel = GoogleFonts.poppins(
    fontSize: 16, fontWeight: FontWeight.w700,
    color: Colors.white, letterSpacing: 0.5,
  );
  static TextStyle price = GoogleFonts.poppins(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: AppColors.goldDeep, letterSpacing: 0.2,
  );
  static TextStyle priceLarge = GoogleFonts.playfairDisplay(
    fontSize: 30, fontWeight: FontWeight.w700,
    color: AppColors.goldDeep, letterSpacing: 0.5,
  );
}
