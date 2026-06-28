import 'package:flutter/material.dart';

import '../pairy_game.dart';
import '../../core/app_colors.dart';

/// On-screen D-pad overlay drawn on top of [GameWidget].
///
/// Layout matches the wireframe:
///   - Bottom-left  → LEFT + RIGHT arrow buttons
///   - Bottom-right → UP (jump) button
///
/// Uses raw [GestureDetector] with `onTapDown`/`onTapUp`/`onTapCancel`
/// so holding a button sustains movement (crucial for a platformer).
class HudControlsOverlay extends StatelessWidget {
  const HudControlsOverlay({super.key, required this.game});

  final PairyGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Left / Right arrows — bottom-left
        Positioned(
          left: 12,
          bottom: 16,
          child: Row(
            children: [
              _HudButton(
                icon: Icons.arrow_back,
                onDown: game.pressLeft,
                onUp: game.releaseHorizontal,
              ),
              const SizedBox(width: 8),
              _HudButton(
                icon: Icons.arrow_forward,
                onDown: game.pressRight,
                onUp: game.releaseHorizontal,
              ),
            ],
          ),
        ),

        // Jump arrow — bottom-right
        Positioned(
          right: 16,
          bottom: 16,
          child: _HudButton(
            icon: Icons.arrow_upward,
            onDown: game.pressJump,
            onUp: () {}, // jump is a one-shot; no release action needed
          ),
        ),
      ],
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.icon,
    required this.onDown,
    required this.onUp,
  });

  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 28),
      ),
    );
  }
}
