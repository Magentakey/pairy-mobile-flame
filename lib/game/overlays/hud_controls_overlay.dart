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
        // ── Left / Right ────────────────────────────────────────────
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

        // ── Jump / Exit ─────────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: 16,
          child: ValueListenableBuilder<bool>(
            valueListenable: game.nearExitDoor,
            builder: (context, isNearDoor, _) => _HudButton(
              icon: Icons.arrow_upward,
              onDown: game.pressJump,
              onUp: () {},
              activeColor: isNearDoor ? const Color(0xFF34C77B) : null,
            ),
          ),
        ),
        // ── Pause button — top right ─────────────────────────────────
        Positioned(
          right: 12,
          top: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: game.togglePause,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
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
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: (activeColor ?? AppColors.surfaceMuted).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 36),
      ),
    );
  }
}