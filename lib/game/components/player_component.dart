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
  static const double maxDt        = 1 / 30;

  final Vector2 velocity      = Vector2.zero();
  final Vector2 _prevPosition = Vector2.zero();
  bool isOnGround    = false;
  bool _nearExitDoor = false;
  LeverComponent? _nearLever;
  _HorizontalInput _input = _HorizontalInput.none;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  void moveLeft()   => _input = _HorizontalInput.left;
  void moveRight()  => _input = _HorizontalInput.right;
  void stopMoving() => _input = _HorizontalInput.none;

  /// Prioritas ↑:
  /// 1. Dekat lever  → aktifkan lever (tidak jump)
  /// 2. Dekat exit   → selesaikan level
  /// 3. Di tanah     → lompat
  void jump() {
    if (_nearLever != null) { _nearLever!.activate(); return; }
    if (_nearExitDoor) { game.completeLevel(); return; }
    if (isOnGround) { velocity.y = jumpVelocity; isOnGround = false; }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final safeDt = dt.clamp(0.0, maxDt);

    switch (_input) {
      case _HorizontalInput.left:  velocity.x = -moveSpeed;
      case _HorizontalInput.right: velocity.x =  moveSpeed;
      case _HorizontalInput.none:  velocity.x = 0;
    }

    velocity.y += gravity * safeDt;
    isOnGround  = false;

    _prevPosition.setFrom(position);
    position += velocity * safeDt;

    for (final ground in game.groundComponents) {
      _resolveAgainst(ground);
    }

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

  void _resolveAgainst(PositionComponent other) {
    final ox = other.absolutePosition.x - absolutePosition.x + position.x;
    final oy = other.absolutePosition.y - absolutePosition.y + position.y;
    final ow = other.size.x;
    final oh = other.size.y;

    final overlapR = (position.x + size.x) - ox;
    final overlapL = (ox + ow) - position.x;
    final overlapB = (position.y + size.y) - oy;
    final overlapT = (oy + oh) - position.y;

    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) return;

    final prevBottom = _prevPosition.y + size.y;
    final prevTop    = _prevPosition.y;
    final prevRight  = _prevPosition.x + size.x;
    final prevLeft   = _prevPosition.x;

    if (prevBottom <= oy) {
      position.y = oy - size.y;
      if (velocity.y > 0) { velocity.y = 0; isOnGround = true; }
    } else if (prevTop >= oy + oh) {
      position.y = oy + oh;
      if (velocity.y < 0) velocity.y = 0;
    } else if (prevRight <= ox) {
      position.x = ox - size.x;
      velocity.x = 0;
    } else if (prevLeft >= ox + ow) {
      position.x = ox + ow;
      velocity.x = 0;
    } else {
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
    if (other is LeverComponent)    _nearLever    = other;
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExitDoorComponent) _nearExitDoor = false;
    if (other is LeverComponent && _nearLever == other) _nearLever = null;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2ECC71));
  }
}
