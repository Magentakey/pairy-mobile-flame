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

  // Daftar level — tambah 'level-02' dst saat map baru siap
  static const List<String> _levelNames = ['level-01'];
  int _currentLevelIndex = 0;

  final VoidCallback? onLevelComplete;

  PlayerComponent? player;
  late Level _level;
  late CameraComponent cam;

  @override
  Future<void> onLoad() async {
    await _loadLevel();
  }

  Future<void> _loadLevel() async {
    _level = Level(levelName: _levelNames[_currentLevelIndex]);
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

  // ── Level complete ───────────────────────────────────────────────
  void completeLevel() {
    pauseEngine();
    overlays.add('LevelComplete');
  }

  /// Dipanggil dari overlay "LevelComplete" saat user tekan tombol lanjut.
  Future<void> loadNextLevel() async {
    overlays.remove('LevelComplete');

    if (_currentLevelIndex < _levelNames.length - 1) {
      _currentLevelIndex++;
    } else {
      // Tidak ada level berikutnya — ulangi level terakhir
      // Nanti ganti dengan navigasi ke MapSelect
    }

    // Hapus level lama, muat yang baru
    removeAll(children.toList());
    player = null;
    await Future.delayed(const Duration(milliseconds: 300));
    await _loadLevel();
    resumeEngine();
  }

  // ── Restart level ────────────────────────────────────────────────
  Future<void> restartLevel() async {
    overlays.remove('LevelComplete');
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
