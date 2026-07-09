import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/overlays/hud_controls_overlay.dart';
import '../game/overlays/lever_button_overlay.dart';
import '../game/overlays/level_complete_overlay.dart';
import '../game/overlays/pause_overlay.dart';
import '../game/overlays/player_died_overlay.dart';
import '../game/pairy_game.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, required this.levelIndex});
  final int levelIndex;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late final PairyGame _game;

  @override
  void initState() {
    super.initState();
    _game = PairyGame(
      levelIndex: widget.levelIndex,
      onBackToMap: () {
        if (mounted) Navigator.pushReplacementNamed(context, '/map-select');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: GameWidget<PairyGame>(
        game: _game,
        overlayBuilderMap: {
          'HudControls':   (ctx, g) => HudControlsOverlay(game: g),
          'LeverButton':   (ctx, g) => LeverButtonOverlay(game: g),
          'Paused':        (ctx, g) => PauseOverlay(game: g),
          'PlayerDied':    (ctx, g) => PlayerDiedOverlay(game: g),
          'LevelComplete': (ctx, g) => LevelCompleteOverlay(game: g),
        },
        initialActiveOverlays: const ['HudControls'],
      ),
    );
  }
}
