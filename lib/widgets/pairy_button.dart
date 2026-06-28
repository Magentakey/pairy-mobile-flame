import 'package:flutter/material.dart';

/// Small rounded flat button matching the wireframe's button style — used
/// across Home, Pause, and Map screens for visual consistency.
class PairyButton extends StatelessWidget {
  const PairyButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.width,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }
}
