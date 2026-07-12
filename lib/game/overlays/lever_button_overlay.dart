import 'package:flutter/material.dart';

import '../pairy_game.dart';

class LeverButtonOverlay extends StatelessWidget {
  const LeverButtonOverlay({super.key, required this.game});

  final PairyGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.leverState,
      builder: (context, isOn, _) => Positioned(
        right: 100,
        bottom: 16,
        child: GestureDetector(
          onTap: game.activateLever,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: (isOn ? const Color(0xFF34C77B) : const Color(0xFF666688))
                  .withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isOn ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}