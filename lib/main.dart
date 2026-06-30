import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/overlays/hud_controls_overlay.dart';
import 'game/pairy_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();

  final game = PairyGame();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: GameWidget<PairyGame>(
          game: game,
          overlayBuilderMap: {
            'HudControls': (context, game) =>
                HudControlsOverlay(game: game),
            'LeverButton': (context, game) =>
                _LeverButtonOverlay(game: game),
            'LevelComplete': (context, game) =>
                _LevelCompleteOverlay(game: game),
          },
          initialActiveOverlays: const ['HudControls'],
        ),
      ),
    ),
  );
}

// ── Tombol lever — muncul di sebelah kiri tombol ↑ ─────────────────
class _LeverButtonOverlay extends StatelessWidget {
  const _LeverButtonOverlay({required this.game});
  final PairyGame game;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 84, // sebelah kiri tombol ↑ (16 + 52 + 16)
      bottom: 16,
      child: GestureDetector(
        onTap: game.activateLever,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF34C77B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.toggle_on_rounded,
              color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

// ── Level complete overlay ──────────────────────────────────────────
class _LevelCompleteOverlay extends StatelessWidget {
  const _LevelCompleteOverlay({required this.game});
  final PairyGame game;

  @override
  Widget build(BuildContext context) {
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
                const Text('🎉',
                    style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                const Text(
                  'Level Selesai!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Btn(label: 'Ulangi', icon: Icons.replay_rounded,
                        color: const Color(0xFF444466),
                        onTap: game.restartLevel),
                    const SizedBox(width: 14),
                    _Btn(label: 'Lanjut',
                        icon: Icons.arrow_forward_rounded,
                        color: const Color(0xFF34C77B),
                        onTap: game.loadNextLevel),
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

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                )),
          ],
        ),
      ),
    );
  }
}
