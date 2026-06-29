import 'dart:math' show min;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../pairy_game.dart';
import 'exit_door_component.dart';
import 'gate_component.dart';
import 'ground_component.dart';
import 'lever_component.dart';

enum _HorizontalInput { none, left, right }

class PlayerComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PairyGame> {
  PlayerComponent({required super.position}) : super(size: Vector2(26, 34));

  static const double moveSpeed    = 130;
  static const double gravity      = 700;
  static const double jumpVelocity = -300;
  // dt maksimum ~33ms (setara 30fps) — cegah lompatan besar di frame lambat
  static const double maxDt        = 1 / 30;

  final Vector2 velocity      = Vector2.zero();
  final Vector2 _prevPosition = Vector2.zero();
  bool isOnGround   = false;
  bool _nearExitDoor = false;
  _HorizontalInput _input = _HorizontalInput.none;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  void moveLeft()   => _input = _HorizontalInput.left;
  void moveRight()  => _input = _HorizontalInput.right;
  void stopMoving() => _input = _HorizontalInput.none;

  void jump() {
    if (_nearExitDoor) { game.completeLevel(); return; }
    if (isOnGround) { velocity.y = jumpVelocity; isOnGround = false; }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Cap dt — cegah player menembus lantai di frame pertama yang lambat
    final safeDt = dt.clamp(0.0, maxDt);

    switch (_input) {
      case _HorizontalInput.left:  velocity.x = -moveSpeed;
      case _HorizontalInput.right: velocity.x =  moveSpeed;
      case _HorizontalInput.none:  velocity.x = 0;
    }

    velocity.y += gravity * safeDt;
    isOnGround  = false;

    // Simpan posisi sebelum bergerak — dipakai resolusi collision
    _prevPosition.setFrom(position);
    position += velocity * safeDt;

    // Ground collision dari list langsung (tidak lewat parent.children)
    for (final ground in game.groundComponents) {
      _resolveAgainst(ground);
    }

    // Gate & lever (jumlah sedikit, bisa lewat children)
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is GateComponent && !child.isOpenState) {
          _resolveAgainst(child);
        } else if (child is LeverComponent) {
          _resolveAgainst(child);
        }
      }
    }
  }

  /// Resolusi AABB berbasis prevPosition.
  ///
  /// Daripada membandingkan overlap terkecil (yang ambiguous di sudut),
  /// kita lihat dari arah mana player datang sebelum frame ini.
  /// Ini menghilangkan bug "teleport ke bawah platform saat di tepi".
  void _resolveAgainst(PositionComponent other) {
    final ox = other.position.x;
    final oy = other.position.y;
    final ow = other.size.x;
    final oh = other.size.y;

    final overlapR = (position.x + size.x) - ox;
    final overlapL = (ox + ow) - position.x;
    final overlapB = (position.y + size.y) - oy;
    final overlapT = (oy + oh) - position.y;

    // Tidak ada tumpang-tindih — skip
    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) return;

    final prevBottom = _prevPosition.y + size.y;
    final prevTop    = _prevPosition.y;
    final prevRight  = _prevPosition.x + size.x;
    final prevLeft   = _prevPosition.x;

    if (prevBottom <= oy) {
      // Player sebelumnya di ATAS tile → mendarat di atas
      position.y = oy - size.y;
      if (velocity.y > 0) { velocity.y = 0; isOnGround = true; }
    } else if (prevTop >= oy + oh) {
      // Player sebelumnya di BAWAH tile → membentur bawah tile
      position.y = oy + oh;
      if (velocity.y < 0) velocity.y = 0;
    } else if (prevRight <= ox) {
      // Player sebelumnya di KIRI tile → dorong ke kiri
      position.x = ox - size.x;
      velocity.x = 0;
    } else if (prevLeft >= ox + ow) {
      // Player sebelumnya di KANAN tile → dorong ke kanan
      position.x = ox + ow;
      velocity.x = 0;
    } else {
      // Ambiguous (spawn di dalam tile) → fallback min-overlap
      final minX = min(overlapR, overlapL);
      final minY = min(overlapB, overlapT);
      if (minY <= minX) {
        if (velocity.y >= 0) {
          position.y = oy - size.y;
          velocity.y = 0;
          isOnGround = true;
        } else {
          position.y = oy + oh;
          velocity.y = 0;
        }
      } else {
        position.x = overlapR <= overlapL ? ox - size.x : ox + ow;
        velocity.x = 0;
      }
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is ExitDoorComponent) _nearExitDoor = true;
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExitDoorComponent) _nearExitDoor = false;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2ECC71));
  }
}
