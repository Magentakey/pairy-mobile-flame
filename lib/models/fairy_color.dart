import 'package:flutter/material.dart';

/// The colors a fairy (and the fountain it activates) can have. Extend
/// this list as new puzzle colors are introduced (PRD 6.6–6.7: fairy
/// mechanic + fountain matching by color).
enum FairyColor {
  blue,
  red,
  green,
  yellow;

  Color get displayColor => switch (this) {
        FairyColor.blue => const Color(0xFF3498DB),
        FairyColor.red => const Color(0xFFE74C3C),
        FairyColor.green => const Color(0xFF2ECC71),
        FairyColor.yellow => const Color(0xFFF1C40F),
      };
}
