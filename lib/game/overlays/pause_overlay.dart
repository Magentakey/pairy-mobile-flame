import 'package:flutter/material.dart';

import '../pairy_game.dart';
import 'overlay_button.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});
  final PairyGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Paused',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OverlayButton(
                        label: 'Resume',
                        icon: Icons.play_arrow_rounded,
                        color: const Color(0xFF34C77B),
                        onTap: game.resumeFromPause,
                        fullWidth: true,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OverlayButton(
                        label: 'Restart',
                        icon: Icons.replay_rounded,
                        color: const Color(0xFFE85C4A),
                        onTap: game.restartLevel,
                        fullWidth: true,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OverlayButton(
                  label: 'Back to Map',
                  icon: Icons.map_outlined,
                  color: const Color(0xFF333355),
                  onTap: game.backToMap,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
