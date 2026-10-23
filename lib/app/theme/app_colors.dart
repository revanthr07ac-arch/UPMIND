import 'package:flutter/material.dart';

/// UPMIND Design System Color Palette
/// Premium dark navy theme with soft violet and blue accents
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF080B12);
  static const Color navBackground = Color(0xFF0E1322);
  static const Color card = Color(0xFF141A2D);
  static const Color cardElevated = Color(0xFF1B233C);
  static const Color cardHover = Color(0xFF1F2947);
  static const Color inputBackground = Color(0xFF0D1222);

  // Borders
  static const Color border = Color(0xFF232C46);
  static const Color borderLight = Color(0xFF2E3B5D);
  static const Color borderFocus = Color(0xFF4F7CFF);

  // Brand Accents
  static const Color primaryBlue = Color(0xFF4F7CFF);
  static const Color primaryBlueHover = Color(0xFF3B68EB);
  static const Color secondaryViolet = Color(0xFF8B5CF6);
  static const Color violetHover = Color(0xFF7C3AED);

  // Text
  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textSecondary = Color(0xFFA6AEC8);
  static const Color textMuted = Color(0xFF6B728E);
  static const Color textInverse = Color(0xFF080B12);

  // Status & Feedback (Accessible)
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0x1F10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0x1FEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0x1FF59E0B);
  static const Color info = Color(0xFF38BDF8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, secondaryViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [card, cardElevated],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient subtleGlassGradient = LinearGradient(
    colors: [Color(0x144F7CFF), Color(0x088B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
