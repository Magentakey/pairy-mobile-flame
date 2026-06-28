import 'package:flutter/material.dart';

import '../pairy_game.dart';
import '../../core/app_colors.dart';

class HudControlsOverlay extends StatelessWidget {
  const HudControlsOverlay({super.key, required this.game});

  final PairyGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
        Positioned(
          right: 16,
          bottom: 16,
          child: _HudButton(
            icon: Icons.arrow_upward,
            onDown: game.pressJump,
            onUp: () {},
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
          color: AppColors.surfaceMuted.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.85),
          size: 28,
        ),
      ),
    );
  }
}
