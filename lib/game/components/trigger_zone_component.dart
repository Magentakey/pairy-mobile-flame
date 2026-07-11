import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'player_component.dart';

/// Invisible trigger zone — `isOn` bernilai true selama [PlayerComponent]
/// overlap dengan area ini, dan otomatis false lagi begitu player keluar.
/// Tidak ada render sama sekali (murni logic) dan hitbox-nya passive,
/// jadi tidak menghalangi gerakan player sama sekali.
///
/// Pairing ke target lain (Gate/MovingPlatform/MapText) lewat `name`
/// object di Tiled — persis pola yang sama dengan Lever/Fountain, lihat
/// `_TriggerGroup` di level.dart. Artinya satu trigger zone bisa dipakai
/// bareng untuk membuka gate, menjalankan moving platform, DAN
/// memunculkan text sekaligus, asal semuanya share `name` yang sama.
class TriggerZoneComponent extends PositionComponent with CollisionCallbacks {
  TriggerZoneComponent({
    required super.position,
    required super.size,
    this.onToggle,
    this.permanent = true,
  });

  /// Dipanggil setiap kali [isOn] berubah (baik jadi true maupun false).
  final VoidCallback? onToggle;

  /// True (default) = sekali kesentuh, langsung terkunci ON selamanya —
  /// player tidak perlu berdiri terus di zona ini.
  /// False = harus tetap ada di dalam zona supaya tetap ON; begitu
  /// player keluar, langsung balik OFF.
  final bool permanent;

  bool _isOn = false;
  bool get isOn => _isOn;

  // Sekali true (hanya kalau [permanent]), state dikunci ON selamanya dan
  // event overlap berikutnya diabaikan.
  bool _locked = false;

  // Counter (bukan bool tunggal) sebagai jaga-jaga kalau suatu saat ada
  // lebih dari satu hitbox player yang overlap zona ini secara bersamaan
  // — konsisten dengan fix multi-overlap ExitDoor/Lever sebelumnya.
  int _touchingPlayers = 0;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerComponent) {
      _touchingPlayers++;
      _updateState();
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is PlayerComponent) {
      _touchingPlayers = (_touchingPlayers - 1).clamp(0, 1 << 30);
      _updateState();
    }
  }

  void _updateState() {
    if (_locked) return;
    final shouldBeOn = _touchingPlayers > 0;
    if (shouldBeOn != _isOn) {
      _isOn = shouldBeOn;
      onToggle?.call();
      if (permanent && _isOn) {
        _locked = true;
      }
    }
  }
}
