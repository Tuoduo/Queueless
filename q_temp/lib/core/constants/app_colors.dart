import 'package:flutter/material.dart';

class AppColors {
  // Primary palette — richer, deeper purples
  static const Color primary = Color(0xFF7B6FFF);
  static const Color primaryLight = Color(0xFFADA4FF);
  static const Color primaryDark = Color(0xFF5046CC);

  // Secondary palette — vibrant teal/cyan
  static const Color secondary = Color(0xFF00E5C3);
  static const Color secondaryLight = Color(0xFF5EFFD4);
  static const Color secondaryDark = Color(0xFF00A882);

  // Accent — warm coral for highlights
  static const Color accent = Color(0xFFFF6B8A);
  static const Color accentLight = Color(0xFFFF9EB7);

  // Background — deep space-like dark
  static const Color background = Color(0xFF0A0A1A);
  static const Color surface = Color(0xFF141428);
  static const Color surfaceLight = Color(0xFF1E1E3A);
  static const Color card = Color(0xFF181834);
  static const Color divider = Color(0xFF2A2A50);

  // Glass — subtle translucency
  static const Color glassWhite = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x28FFFFFF);
  static const Color glassOverlay = Color(0x0AFFFFFF);
  static const Color glassHighlight = Color(0x1EFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFF5F5FF);
  static const Color textSecondary = Color(0xFFB8B5D4);
  static const Color textHint = Color(0xFF6E6B90);

  // Status — refined tones
  static const Color success = Color(0xFF2DD4A8);
  static const Color warning = Color(0xFFFFB347);
  static const Color error = Color(0xFFFF5C6B);
  static const Color info = Color(0xFF64B5F6);

  // VIP
  static const Color vip = Color(0xFFFFD700);

  // Neon glow accents
  static const Color neonPurple = Color(0xFFB388FF);
  static const Color neonCyan = Color(0xFF18FFFF);

  // Gradient — Primary button / hero sections
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7B6FFF), Color(0xFF9C5FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF181834), Color(0xFF1A1A3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondary, Color(0xFF00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF7B6FFF), Color(0xFF00E5C3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glass card gradient overlay
  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x18FFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Subtle card border gradient
  static const LinearGradient borderGradient = LinearGradient(
    colors: [Color(0x40FFFFFF), Color(0x10FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Serving status glow gradient
  static const LinearGradient servingGradient = LinearGradient(
    colors: [Color(0xFF00E5C3), Color(0xFF18FFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x33FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );
}
