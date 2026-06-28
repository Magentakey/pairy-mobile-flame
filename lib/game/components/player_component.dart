import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../pairy_game.dart';
import 'exit_door_component.dart';
import 'gate_component.dart';
import 'ground_component.dart';
import 'lever_component.dart';

enum _HorizontalInput { none, left, right }

/// The player-controlled character (PRD 6.1–6.3).
///
/// Movement is driven by [moveLeft]/[moveRight]/[stopMoving]/[jump], which
/// are called by `HudControlsOverlay` rather than reading raw input here —
/// that keeps this component testable and input-method-agnostic (works the
/// same whether the trigger is an on-screen button, a keyboard, or a
/// gamepad later on).
///
/// Collision is resolved with a deliberately simple AABB approach: good
/// enough for a flat/staircase MVP level, not meant to survive slopes or
/// fast-moving platforms. Swap for a proper resolver if the design grows.
class PlayerComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PairyGame> {
  PlayerComponent({required super.position}) : super(size: Vector2(26, 34));

  static const double moveSpeed = 130; // px/s
  static const double gravity = 700; // px/s^2
  static const double jumpVelocity = -300; // px/s (negative = upward)

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

  /// PRD 6.3: pressing jump while near the exit door completes the level
  /// instead of making the player actually jump.
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

    // Re-confirmed true this frame by onCollision below if still resting
    // on something solid; otherwise the player has walked off a ledge.
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
    if (other is ExitDoorComponent) {
      _nearExitDoor = true;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    _handleSolidCollision(other);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExitDoorComponent) {
      _nearExitDoor = false;
    }
  }

  /// Treats ground, closed gates, and levers as solid (PRD 6.2), landing
  /// the player on top of them when falling onto their upper edge.
  void _handleSolidCollision(PositionComponent other) {
    final isSolid = other is GroundComponent ||
        (other is GateComponent && !other.isOpenState) ||
        other is LeverComponent;
    if (!isSolid) return;

    final otherTop = other.position.y;
    final playerBottom = position.y + size.y;

    if (velocity.y >= 0 && playerBottom - otherTop < 14) {
      position.y = otherTop - size.y;
      velocity.y = 0;
      isOnGround = true;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2ECC71));
  }
}
