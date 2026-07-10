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

  static const Color background = Color.fromARGB(255, 73, 114, 108);
  static const Color panel = Color(0xFF2E2B45);
  static const Color panelHeader = Color(0xFF3D3960);
  static const Color surfaceMuted = Color(0xFF56507F);

  static const Color primaryGreen = Color(0xFF34C77B);
  static const Color dangerRed = Color(0xFFE85C4A);

  static const Color levelLocked = Color(0xFF9E9E9E);
}
