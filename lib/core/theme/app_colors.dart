import 'package:flutter/material.dart';

/// Glamzo Premium Palette — warm cream + rich antique gold
/// Matching the shared reference image exactly
class AppColors {
  AppColors._();

  // ── Backgrounds / Surfaces ──
  static const Color bg         = Color(0xFFF5ECD7); // warm cream (image bg)
  static const Color bg2        = Color(0xFFEDE0C8); // slightly deeper cream
  static const Color bg3        = Color(0xFFE5D4B3); // warm parchment
  static const Color card       = Color(0xFFFFFFFF); // pure white cards
  static const Color card2      = Color(0xFFFDF8F0); // soft cream card
  static const Color surface    = Color(0xFFF5ECD7);
  static const Color surface2   = Color(0xFFEDE0C8);
  static const Color surface3   = Color(0xFFE5D4B3);
  static const Color cardWhite  = Color(0xFFFFFFFF);

  // ── Borders ──
  static const Color border     = Color(0xFFE8D9C0);
  static const Color border2    = Color(0xFFD9C9A8);
  static const Color border3    = Color(0xFFC4AD88);

  // ── Text ──
  static const Color ink        = Color(0xFF1A1208); // near black
  static const Color ink2       = Color(0xFF2A1E0E);
  static const Color ink3       = Color(0xFF3A2A14);
  static const Color text2      = Color(0xFF4A3820);
  static const Color text3      = Color(0xFF7A6040);
  static const Color text4      = Color(0xFF9E8060);

  // ── Rich Antique Gold (primary accent — matching image buttons/icons) ──
  static const Color gold       = Color(0xFFC9971A); // rich antique gold
  static const Color gold2      = Color(0xFFD4A826); // slightly lighter
  static const Color gold3      = Color(0xFFE8C040); // highlight gold
  static const Color goldDeep   = Color(0xFF8B6510); // deep amber
  static const Color goldBg     = Color(0xFFFBF2DC); // gold tinted bg
  static const Color goldBg2    = Color(0xFFF5E4B8); // deeper gold bg
  static const Color goldBorder = Color(0xFFD4A826); // gold border

  // ── Deep Brown (section dividers, dark elements) ──
  static const Color charcoal   = Color(0xFF1A1208);
  static const Color charcoal2  = Color(0xFF2A1E0E);

  // ── Rose / Accent ──
  static const Color rose       = Color(0xFFC4796A);
  static const Color rose2      = Color(0xFFD9917E);
  static const Color roseBg     = Color(0xFFFAF0EC);
  static const Color roseBorder = Color(0xFFE8C4B8);

  // ── Sage / Success ──
  static const Color sage       = Color(0xFF6B8C6E);
  static const Color sage2      = Color(0xFF89AD8C);
  static const Color sageBg     = Color(0xFFEEF4EE);
  static const Color sageBorder = Color(0xFFC4D8C4);

  // ── Espresso (dark hero elements) ──
  static const Color espresso   = Color(0xFF1C1208);
  static const Color espresso2  = Color(0xFF2E1E0A);

  // ── Gradients ──
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4A826), Color(0xFF8B6510)],
  );

  // Hero uses warm cream NOT dark — matching image
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5ECD7), Color(0xFFEDE0C8)],
  );

  static const LinearGradient creamGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF5ECD7)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFDF8F0)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5ECD7), Color(0xFFEDE0C8)],
  );

  static const LinearGradient goldShimmer = LinearGradient(
    colors: [Color(0xFFC9971A), Color(0xFFE8C040), Color(0xFFC9971A)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient shimmer = LinearGradient(
    colors: [Color(0xFFEDE0C8), Color(0xFFF5ECD7), Color(0xFFEDE0C8)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1208), Color(0xFF2A1E0E), Color(0xFF3A2008)],
  );

  // Legacy aliases
  static const Color borderGold = goldBorder;
  static const Color glass      = Color(0x14000000);
  static const Color glassGold  = Color(0x18C9971A);
}