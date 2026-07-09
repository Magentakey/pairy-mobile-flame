import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Text('PAIRY',
                    style: TextStyle(
                      fontSize: 72, fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 6
                        ..color = Colors.white.withValues(alpha: 0.2),
                    )),
                const Text('PAIRY',
                    style: TextStyle(
                      fontSize: 72, fontWeight: FontWeight.w900,
                      letterSpacing: 8, color: Colors.white,
                      decoration: TextDecoration.none,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text('Puzzle Platformer',
                style: TextStyle(
                  fontSize: 13, letterSpacing: 3,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                )),
            const SizedBox(height: 56),
            _Btn(label: 'Play', color: AppColors.primaryGreen,
                onTap: () => Navigator.pushNamed(context, '/map-select')),
            const SizedBox(height: 16),
            _Btn(label: 'Quit', color: AppColors.dangerRed,
                onTap: SystemNavigator.pop),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color,
            borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
              color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w700, letterSpacing: 1,
              decoration: TextDecoration.none,
            )),
      ),
    );
  }
}
