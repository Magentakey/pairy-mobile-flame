import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The level goal (PRD 6.3). Per the PRD the player finishes the level by
/// pressing the jump button while standing near this door — see
/// `PlayerComponent.jump()`, which checks the proximity flag this
/// component's collision callbacks set.
class ExitDoorComponent extends PositionComponent with CollisionCallbacks {
  ExitDoorComponent({required super.position}) : super(size: Vector2(26, 40));

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = Colors.white);
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = const Color(0xFF424242)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
