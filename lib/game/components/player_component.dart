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

  // Public supaya PairyGame bisa akses untuk activateLever()
  LeverComponent? nearLever;

  _HorizontalInput _input = _HorizontalInput.none;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  void moveLeft()   => _input = _HorizontalInput.left;
  void moveRight()  => _input = _HorizontalInput.right;
  void stopMoving() => _input = _HorizontalInput.none;

  // ↑ = lompat atau selesaikan level (lever pakai tombol HUD sendiri)
  void jump() {
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
    position   += velocity * safeDt;

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
    final ox = other.position.x;
    final oy = other.position.y;
    final ow = other.size.x;
    final oh = other.size.y;

    // Lever pakai anchor bottomCenter — sesuaikan posisi
    final resolvedOx = (other.anchor == Anchor.bottomCenter)
        ? ox - ow / 2
        : ox;
    final resolvedOy = (other.anchor == Anchor.bottomCenter)
        ? oy - oh
        : oy;

    final overlapR = (position.x + size.x) - resolvedOx;
    final overlapL = (resolvedOx + ow) - position.x;
    final overlapB = (position.y + size.y) - resolvedOy;
    final overlapT = (resolvedOy + oh) - position.y;

    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) return;

    final prevBottom = _prevPosition.y + size.y;
    final prevTop    = _prevPosition.y;
    final prevRight  = _prevPosition.x + size.x;
    final prevLeft   = _prevPosition.x;

    if (prevBottom <= resolvedOy) {
      position.y = resolvedOy - size.y;
      if (velocity.y > 0) { velocity.y = 0; isOnGround = true; }
    } else if (prevTop >= resolvedOy + oh) {
      position.y = resolvedOy + oh;
      if (velocity.y < 0) velocity.y = 0;
    } else if (prevRight <= resolvedOx) {
      position.x = resolvedOx - size.x;
      velocity.x = 0;
    } else if (prevLeft >= resolvedOx + ow) {
      position.x = resolvedOx + ow;
      velocity.x = 0;
    } else {
      final minX = min(overlapR, overlapL);
      final minY = min(overlapB, overlapT);
      if (minY <= minX) {
        if (velocity.y >= 0) {
          position.y = resolvedOy - size.y;
          velocity.y = 0; isOnGround = true;
        } else {
          position.y = resolvedOy + oh;
          velocity.y = 0;
        }
      } else {
        position.x = overlapR <= overlapL
            ? resolvedOx - size.x
            : resolvedOx + ow;
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
    if (other is LeverComponent) {
      nearLever = other;
      game.overlays.add('LeverButton'); // tampilkan tombol lever di HUD
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExitDoorComponent) _nearExitDoor = false;
    if (other is LeverComponent && nearLever == other) {
      nearLever = null;
      game.overlays.remove('LeverButton'); // sembunyikan tombol lever
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2ECC71));
  }
}
