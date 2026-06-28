import 'package:flame/camera.dart';
import 'package:flame/collisions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/player_component.dart';
import 'pairy_world.dart';

class PairyGame extends FlameGame<PairyWorld> with HasCollisionDetection {
  PairyGame({this.onLevelComplete})
      : super(
          world: PairyWorld(),
          camera: CameraComponent.withFixedResolution(
            width: virtualWidth,
            height: virtualHeight,
          ),
        );

  static const double virtualWidth = 480;
  static const double virtualHeight = 270;

  final VoidCallback? onLevelComplete;

  PlayerComponent get player => world.player;

  void completeLevel() => onLevelComplete?.call();

  Future<void> restartLevel() => world.buildDemoLevel();

  void pressLeft() => player.moveLeft();
  void pressRight() => player.moveRight();
  void releaseHorizontal() => player.stopMoving();
  void pressJump() => player.jump();
}
