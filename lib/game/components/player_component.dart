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

  static const double moveSpeed = 130;
  static const double gravity = 700;
  static const double jumpVelocity = -300;

  final Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
  bool _nearExitDoor = false;
  _HorizontalInput _input = _HorizontalInput.none;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  void moveLeft() => _input = _HorizontalInput.left;
  void moveRight() => _input = _HorizontalInput.right;
  void stopMoving() => _input = _HorizontalInput.none;

  void jump() {
    if (_nearExitDoor) {
      game.completeLevel();
      return;
    }
    if (isOnGround) {
      velocity.y = jumpVelocity;
      isOnGround = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (_input) {
      case _HorizontalInput.left:
        velocity.x = -moveSpeed;
      case _HorizontalInput.right:
        velocity.x = moveSpeed;
      case _HorizontalInput.none:
        velocity.x = 0;
    }

    velocity.y += gravity * dt;

    // Reset setiap frame — dikonfirmasi ulang oleh onCollision jika masih
    // berdiri di atas solid.
    isOnGround = false;

    position += velocity * dt;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    _handleSolidCollision(other);
    if (other is ExitDoorComponent) _nearExitDoor = true;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    _handleSolidCollision(other);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExitDoorComponent) _nearExitDoor = false;
  }

  /// Resolusi AABB berdasarkan overlap terkecil + arah velocity.
  ///
  /// Tidak pakai threshold pixel tetap — sehingga penetrasi dalam apapun
  /// (misal frame-rate drop atau frame pertama setelah restart) tetap
  /// diselesaikan dengan benar.
  void _handleSolidCollision(PositionComponent other) {
    final isSolid = other is GroundComponent ||
        (other is GateComponent && !other.isOpenState) ||
        other is LeverComponent;
    if (!isSolid) return;

    final ox = other.position.x;
    final oy = other.position.y;
    final ow = other.size.x;
    final oh = other.size.y;

    // Hitung overlap di setiap sisi
    final overlapR = (position.x + size.x) - ox; // sisi kanan player ke kiri solid
    final overlapL = (ox + ow) - position.x;       // sisi kiri player ke kanan solid
    final overlapB = (position.y + size.y) - oy;   // bawah player ke atas solid
    final overlapT = (oy + oh) - position.y;        // atas player ke bawah solid

    // Tidak ada tumpang-tindih nyata (hanya menyentuh atau floating point)
    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) return;

    final minX = min(overlapR, overlapL);
    final minY = min(overlapB, overlapT);

    if (minY <= minX) {
      // ── Resolusi vertikal ────────────────────────────────────────────
      // Gunakan arah velocity (bukan kedalaman penetrasi) agar posisi
      // yang sangat dalam pun tetap benar.
      if (velocity.y >= 0) {
        // Sedang jatuh / berdiri → mendarat di atas permukaan
        position.y = oy - size.y;
        velocity.y = 0;
        isOnGround = true;
      } else {
        // Sedang naik → membentur bagian bawah solid
        position.y = oy + oh;
        velocity.y = 0;
      }
    } else {
      // ── Resolusi horizontal ──────────────────────────────────────────
      if (overlapR <= overlapL) {
        position.x = ox - size.x; // dorong ke kiri
      } else {
        position.x = ox + ow;     // dorong ke kanan
      }
      velocity.x = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2ECC71));
  }
}
