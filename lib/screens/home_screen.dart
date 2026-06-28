import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/routes.dart';
import '../widgets/pairy_button.dart';

/// Home screen (PRD 7.1).
///
/// Wireframe shows:
///   - "PAIRY" bold title centred, outlined style
///   - Green "play" button → navigates to map-select
///   - Red "exit" button  → closes the app
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
            // ── Title: stacked stroke + fill to get the outlined look ──
            Stack(
              children: [
                // Stroke layer
                Text(
                  'PAIRY',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 6
                      ..color = Colors.black87,
                  ),
                ),
                // Fill layer
                const Text(
                  'PAIRY',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 56),

            PairyButton(
              label: 'Play',
              color: AppColors.primaryGreen,
              width: 200,
              onTap: () => Navigator.pushNamed(context, AppRoutes.mapSelect),
            ),

            const SizedBox(height: 20),

            PairyButton(
              label: 'Exit',
              color: AppColors.dangerRed,
              width: 200,
              onTap: () => SystemNavigator.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
