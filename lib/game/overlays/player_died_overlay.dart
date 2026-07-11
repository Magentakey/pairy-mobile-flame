import 'package:flutter/material.dart';

import '../pairy_game.dart';
import 'overlay_button.dart';

class PlayerDiedOverlay extends StatelessWidget {
  const PlayerDiedOverlay({super.key, required this.game});

  final PairyGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.65)),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFE85C4A).withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You Died',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  game.deathCause,
                  style: TextStyle(
                    color: const Color(0xFFE85C4A).withValues(alpha: 0.9),
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OverlayButton(
                      label: 'Retry',
                      icon: Icons.replay_rounded,
                      color: const Color(0xFFE85C4A),
                      onTap: game.restartLevel,
                    ),
                    const SizedBox(width: 12),
                    OverlayButton(
                      label: 'Back to Map',
                      icon: Icons.map_outlined,
                      color: const Color(0xFF444466),
                      onTap: game.backToMap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
