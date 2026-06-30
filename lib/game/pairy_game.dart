import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/ground_component.dart';
import 'components/player_component.dart';
import 'level.dart';

class PairyGame extends FlameGame with HasCollisionDetection {
  PairyGame({this.onLevelComplete});

  static const double gameWidth  = 648;
  static const double gameHeight = 360;
  static const List<String> _levelNames = ['level-01'];
  int _currentLevelIndex = 0;

  final VoidCallback? onLevelComplete;

  PlayerComponent? player;
  late Level _level;
  late CameraComponent cam;

  final ValueNotifier<bool> leverState = ValueNotifier(false);
  // true saat player berada di dekat exit door — dipakai untuk warna tombol ↑
  final ValueNotifier<bool> nearExitDoor = ValueNotifier(false);

  @override
  Future<void> onLoad() async => _loadLevel();

  Future<void> _loadLevel() async {
    _level = Level(levelName: _levelNames[_currentLevelIndex]);
    cam = CameraComponent.withFixedResolution(
      width: gameWidth, height: gameHeight, world: _level,
    );
    await addAll([cam, _level]);
  }

  @override
  Color backgroundColor() => const Color(0xFF211F30);

  List<GroundComponent> get groundComponents => _level.groundComponents;

  void activateLever() {
    player?.nearLever?.activate();
    leverState.value = player?.nearLever?.isOn ?? false;
  }

  void completeLevel() {
    pauseEngine();
    overlays.add('LevelComplete');
  }

  Future<void> loadNextLevel() async {
    overlays.remove('LevelComplete');
    if (_currentLevelIndex < _levelNames.length - 1) _currentLevelIndex++;
    removeAll(children.toList());
    player = null;
    await Future.delayed(const Duration(milliseconds: 300));
    await _loadLevel();
    resumeEngine();
  }

  Future<void> restartLevel() async {
    overlays.remove('LevelComplete');
    player = null;
    _level.groundComponents.clear();
    removeAll(children.toList());
    await Future.delayed(const Duration(milliseconds: 300));
    await _loadLevel();
    resumeEngine();
  }

  void pressLeft()         => player?.moveLeft();
  void pressRight()        => player?.moveRight();
  void releaseHorizontal() => player?.stopMoving();
  void pressJump()         => player?.jump();
}
