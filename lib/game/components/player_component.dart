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

  final Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
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

    switch (_input) {
      case _HorizontalInput.left:  velocity.x = -moveSpeed;
      case _HorizontalInput.right: velocity.x =  moveSpeed;
      case _HorizontalInput.none:  velocity.x = 0;
    }

    velocity.y += gravity * dt;
    isOnGround  = false;
    position   += velocity * dt;

    _checkGroundCollisions();
  }

  void _checkGroundCollisions() {
    if (parent == null) return;
    for (final child in parent!.children) {
      if (child is GroundComponent) {
        _resolveAgainst(child);
      } else if (child is GateComponent && !child.isOpenState) {
        _resolveAgainst(child);
      } else if (child is LeverComponent) {
        _resolveAgainst(child);
      }
    }
  }

  void _resolveAgainst(PositionComponent other) {
    final ox = other.position.x;
    final oy = other.position.y;
    final ow = other.size.x;
    final oh = other.size.y;

    final overlapR = (position.x + size.x) - ox;
    final overlapL = (ox + ow) - position.x;
    final overlapB = (position.y + size.y) - oy;
    final overlapT = (oy + oh) - position.y;

    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) return;

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
