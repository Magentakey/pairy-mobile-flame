import 'package:flame/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/player_component.dart';
import 'pairy_world.dart';

/// Root [FlameGame] class for Pairy.
///
/// Wires the [PairyWorld] to a fixed-resolution camera so the virtual
/// 480 × 270 px canvas always scales pixel-perfectly to the device screen
/// regardless of DPI. 480 × 270 is a 16:9 ratio at a comfortable "pixel
/// art at ~2×" working scale — bump [virtualWidth]/[virtualHeight] here if
/// the tile size chosen in Tiled changes.
class PairyGame extends FlameGame<PairyWorld> {
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

  /// Called by [PlayerComponent.jump] when the player is near the exit door.
  final VoidCallback? onLevelComplete;

  PlayerComponent get player => world.player;

  void completeLevel() => onLevelComplete?.call();

  Future<void> restartLevel() => world.buildDemoLevel();

  // ── HUD pass-throughs ───────────────────────────────────────────────
  void pressLeft() => player.moveLeft();
  void pressRight() => player.moveRight();
  void releaseHorizontal() => player.stopMoving();
  void pressJump() => player.jump();
}
