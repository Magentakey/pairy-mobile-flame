import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/ground_component.dart';
import 'components/player_component.dart';
import 'level/level.dart';

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

  final ValueNotifier<bool> leverState   = ValueNotifier(false);
  final ValueNotifier<bool> nearExitDoor = ValueNotifier(false);

  // Death
  String _deathCause = '';
  String get deathCause => _deathCause;

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

  // ── Lever ────────────────────────────────────────────────────────
  void activateLever() {
    player?.nearLever?.activate();
    leverState.value = player?.nearLever?.isOn ?? false;
  }

  // ── Death ────────────────────────────────────────────────────────
  void playerDied(String cause) {
    _deathCause = cause;
    pauseEngine();
    overlays.add('PlayerDied');
  }

  // ── Level complete ────────────────────────────────────────────────
  void completeLevel() {
    pauseEngine();
    overlays.add('LevelComplete');
  }

  Future<void> loadNextLevel() async {
    overlays.remove('LevelComplete');
    if (_currentLevelIndex < _levelNames.length - 1) _currentLevelIndex++;
    await _resetGame();
  }

  Future<void> restartLevel() async {
    overlays.remove('LevelComplete');
    overlays.remove('PlayerDied');
    nearExitDoor.value = false;
    leverState.value   = false;
    await _resetGame();
  }

  Future<void> _resetGame() async {
    player = null;
    _level.groundComponents.clear();
    removeAll(children.toList());
    await Future.delayed(const Duration(milliseconds: 300));
    await _loadLevel();
    resumeEngine();
  }

  // ── Player pass-throughs ─────────────────────────────────────────
  void pressLeft()         => player?.moveLeft();
  void pressRight()        => player?.moveRight();
  void releaseHorizontal() => player?.stopMoving();
  void pressJump()         => player?.jump();
}
