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
      home: GameWidget<PairyGame>(
        game: game,
        overlayBuilderMap: {
          'HudControls': (context, game) => HudControlsOverlay(game: game),
        },
        initialActiveOverlays: const ['HudControls'],
        errorBuilder: (context, error) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    ),
  );
}
