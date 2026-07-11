import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/ground_component.dart';
import 'components/player_component.dart';
import 'level/level.dart';
import '../services/progress_service.dart';

class PairyGame extends FlameGame with HasCollisionDetection {
  PairyGame({int levelIndex = 0, this.onBackToMap})
    : _currentLevelIndex = levelIndex;

  static const double gameWidth = 648;
  static const double gameHeight = 360;
  static const List<String> levelNames = [
    'tutorial',
    'level-01',
    'level-02',
    'level-03',
    'level-04',
    'level-05',
    'level-06',
    'level-07',
    'level-08',
    'level-09',
    'level-10',
    'level-11',
    'level-12',
  ];

  int _currentLevelIndex;
  final VoidCallback? onBackToMap;

  PlayerComponent? player;
  late Level _level;
  late CameraComponent cam;

  final ValueNotifier<bool> leverState = ValueNotifier(false);
  final ValueNotifier<bool> nearExitDoor = ValueNotifier(false);

  bool _isPaused = false;
  String _deathCause = '';
  String get deathCause => _deathCause;

  // True kalau masih ada level setelah level yang sedang dimainkan sekarang.
  bool get hasNextLevel => _currentLevelIndex < levelNames.length - 1;

  @override
  Future<void> onLoad() async => _loadLevel();

  Future<void> _loadLevel() async {
    final name = levelNames[_currentLevelIndex.clamp(0, levelNames.length - 1)];
    _level = Level(levelName: name);
    cam = CameraComponent.withFixedResolution(
      width: gameWidth,
      height: gameHeight,
      world: _level,
    );
    await addAll([cam, _level]);
  }

  @override
  Color backgroundColor() => const Color(0xFF211F30);

  List<GroundComponent> get groundComponents => _level.groundComponents;
  double get levelHeightPx => _level.heightPx;

  // ── Debug ────────────────────────────────────────────────────────
  // Diaktifkan lewat trigger/lever/fountain khusus di Tiled dengan
  // `name` = "debugmode" (lihat Level._maybeToggleDebugMode). Menyalakan
  // outline hitbox semua komponen collision (player, ground, gate, dll)
  // supaya gampang debug alignment collision vs sprite di lapangan,
  // tanpa perlu rebuild dengan debugMode di-hardcode true.
  void toggleDebugMode() => debugMode = !debugMode;

  // ── Pause ────────────────────────────────────────────────────────
  void togglePause() {
    if (overlays.isActive('PlayerDied') || overlays.isActive('LevelComplete'))
      return;
    if (_isPaused) {
      _isPaused = false;
      overlays.remove('Paused');
      resumeEngine();
    } else {
      _isPaused = true;
      overlays.add('Paused');
      pauseEngine();
    }
  }

  void resumeFromPause() {
    if (!_isPaused) return;
    _isPaused = false;
    overlays.remove('Paused');
    resumeEngine();
  }

  void backToMap() {
    _isPaused = false;
    resumeEngine();
    overlays.remove('Paused');
    overlays.remove('LevelComplete');
    overlays.remove('PlayerDied');
    onBackToMap?.call();
  }

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

  // ── Level complete — simpan progress ─────────────────────────────
  Future<void> completeLevel() async {
    // Level ke-N selesai → unlock level ke-(N+1)
    // _currentLevelIndex 0-based → level number = index + 1
    // Yang di-unlock = level number berikutnya = index + 2
    await ProgressService.unlockLevel(_currentLevelIndex + 2);
    pauseEngine();
    overlays.add('LevelComplete');
  }

  Future<void> loadNextLevel() async {
    overlays.remove('LevelComplete');
    if (hasNextLevel) {
      _currentLevelIndex++;
      await _resetGame();
    }
    // Kalau ini level terakhir, tidak melakukan apa-apa —
    // overlay LevelComplete otomatis tertutup, dan UI overlay
    // (LevelCompleteOverlay) sudah menyediakan tombol "Back to Map"
    // terpisah untuk kondisi ini, jadi tidak perlu auto-redirect.
  }

  Future<void> restartLevel() async {
    overlays.remove('LevelComplete');
    overlays.remove('PlayerDied');
    overlays.remove('Paused');
    _isPaused = false;
    nearExitDoor.value = false;
    leverState.value = false;
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

  void pressLeft() => player?.moveLeft();
  void pressRight() => player?.moveRight();
  void releaseHorizontal() => player?.stopMoving();
  void pressJump() => player?.jump();
}
