import 'package:flutter/material.dart';

import '../pairy_game.dart';
import 'overlay_button.dart';

class LevelCompleteOverlay extends StatelessWidget {
  const LevelCompleteOverlay({super.key, required this.game});
  final PairyGame game;

  @override
  Widget build(BuildContext context) {
    final hasNext = game.hasNextLevel;

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF34C77B).withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasNext ? 'Level Complete' : 'All Levels Complete',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OverlayButton(
                      label: 'Retry',
                      icon: Icons.replay_rounded,
                      color: const Color(0xFF444466),
                      onTap: game.restartLevel,
                    ),
                    const SizedBox(width: 12),
                    // Tombol "Next Level" hanya ditampilkan kalau memang masih ada
                    // level berikutnya. Kalau ini level terakhir, tombol ini
                    // digantikan tempatnya oleh "Back to Map" di baris atas
                    // supaya layout tetap seimbang (2 tombol sejajar).
                    if (hasNext)
                      OverlayButton(
                        label: 'Next Level',
                        icon: Icons.arrow_forward_rounded,
                        color: const Color(0xFF34C77B),
                        onTap: game.loadNextLevel,
                      )
                    else
                      OverlayButton(
                        label: 'Back to Map',
                        icon: Icons.map_outlined,
                        color: const Color(0xFF34C77B),
                        onTap: game.backToMap,
                      ),
                  ],
                ),
                // "Back to Map" kedua ini hanya perlu muncul kalau tombol
                // "Back to Map" belum ditampilkan di atas (yaitu saat masih
                // ada next level, supaya opsi kembali ke map tetap tersedia).
                if (hasNext) ...[
                  const SizedBox(height: 10),
                  OverlayButton(
                    label: 'Back to Map',
                    icon: Icons.map_outlined,
                    color: const Color(0xFF333355),
                    onTap: game.backToMap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
