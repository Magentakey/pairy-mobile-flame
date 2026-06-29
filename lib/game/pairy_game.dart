import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/ground_component.dart';
import 'components/player_component.dart';
import 'level.dart';

class PairyGame extends FlameGame {
  PairyGame({this.onLevelComplete});

  static const double gameWidth  = 648;
  static const double gameHeight = 360;

  final VoidCallback? onLevelComplete;

  PlayerComponent? player;
  late Level _level;
  late CameraComponent cam;

  @override
  Future<void> onLoad() async {
    _level = Level(levelName: 'level-01');
    cam = CameraComponent.withFixedResolution(
      width: gameWidth,
      height: gameHeight,
      world: _level,
    );
    await addAll([cam, _level]);
  }

  @override
  Color backgroundColor() => const Color(0xFF211F30);

  // Exposed untuk PlayerComponent — direct list, tidak lewat children
  List<GroundComponent> get groundComponents => _level.groundComponents;

  // ── Level ────────────────────────────────────────────────────────
  void completeLevel() => onLevelComplete?.call();

  Future<void> restartLevel() async {
    player = null;
    await _level.reload();
  }

  // ── Player pass-throughs ─────────────────────────────────────────
  void pressLeft()         => player?.moveLeft();
  void pressRight()        => player?.moveRight();
  void releaseHorizontal() => player?.stopMoving();
  void pressJump()         => player?.jump();
}
