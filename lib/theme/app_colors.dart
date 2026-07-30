import 'package:flutter/material.dart';

/// Central color palette for Radiant Drop Path.
/// Matches the dark circuit-board / neon aesthetic of the game art.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0A0E1A);
  static const Color panel = Color(0xFF12182B);
  static const Color panelLight = Color(0xFF1B2440);
  static const Color boardBase = Color(0xFF0D1424);
  static const Color gridLine = Color(0xFF2A3A5C);
  static const Color accentCyan = Color(0xFF34E7FF);
  static const Color accentGold = Color(0xFFF3B94E);
  static const Color accentMagenta = Color(0xFFD764F0);
  static const Color textPrimary = Color(0xFFF3F7FF);
  static const Color textSecondary = Color(0xFF93A2C7);
  static const Color success = Color(0xFF52E29A);
  static const Color danger = Color(0xFFFF5C6C);
  static const Color warning = Color(0xFFFFC857);

  // Ball colors, matching collection_sphere sprite order:
  // 0 blue, 1 red, 2 green, 3 yellow, 4 purple, 5 white.
  static const Color ballBlue = Color(0xFF3AA6FF);
  static const Color ballRed = Color(0xFFFF4B4B);
  static const Color ballGreen = Color(0xFF54E06B);
  static const Color ballYellow = Color(0xFFFFD23A);
  static const Color ballPurple = Color(0xFFB157FF);
  static const Color ballWhite = Color(0xFFEAF3FF);
}
