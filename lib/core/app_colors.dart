import 'package:flutter/material.dart';

/// Central palette pulled straight from the grayscale wireframe so every
/// screen stays visually consistent while real art direction (PRD section
/// 9 — minimalist, simple shapes) is still pending.
///
/// Swap these for real design tokens once final art direction is locked,
/// ideally still as a single source of truth here rather than scattered
/// hex codes across widgets.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFD9D9D9);
  static const Color panel = Color(0xFFE8E8E8);
  static const Color panelHeader = Color(0xFFB0B0B0);
  static const Color surfaceMuted = Color(0xFF8C8C8C);

  static const Color primaryGreen = Color(0xFF34C77B);
  static const Color dangerRed = Color(0xFFE85C4A);

  static const Color levelLocked = Color(0xFF9E9E9E);
}
