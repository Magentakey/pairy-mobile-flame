import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/pairy_button.dart';

/// Semi-transparent pause panel drawn on top of the game.
///
/// Controlled from [GameplayScreen] state — not using Flame's built-in
/// overlay manager so we keep all Flutter UI in one place and avoid
/// mixing two overlay systems.
///
/// Matches the wireframe popup: dark scrim → centered card with "Pause"
/// header → Retry / Resume / Exit buttons.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRetry,
    required this.onExit,
  });

  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrim
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withOpacity(0.45)),
        ),

        // Panel
        Center(
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.panelHeader,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Pause',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: PairyButton(
                              label: 'Retry',
                              color: AppColors.primaryGreen,
                              onTap: onRetry,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PairyButton(
                              label: 'Exit',
                              color: AppColors.dangerRed,
                              onTap: onExit,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PairyButton(
                        label: 'Resume',
                        color: AppColors.primaryGreen,
                        onTap: onResume,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
