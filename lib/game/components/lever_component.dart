import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// A puzzle lever the player can tap to flip on/off (PRD 6.4). It is also
/// solid (PRD 6.2 lists "Lever" among things the player collides with),
/// so it mixes both [TapCallbacks] and [CollisionCallbacks].
///
/// Wire a lever to a [onToggle] listener — typically
/// `GateComponent.toggle` — to build simple puzzle logic.
class LeverComponent extends PositionComponent
    with TapCallbacks, CollisionCallbacks {
  LeverComponent({required super.position, this.onToggle})
      : super(size: Vector2(20, 30));

  final void Function(bool isOn)? onToggle;
  bool isOn = false;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void onTapDown(TapDownEvent event) {
    isOn = !isOn;
    onToggle?.call(isOn);
  }

  @override
  void render(Canvas canvas) {
    final base = Paint()..color = const Color(0xFF9E9E9E);
    final handle = Paint()
      ..color = isOn ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    canvas.drawRect(Rect.fromLTWH(0, size.y - 8, size.x, 8), base);
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 3, 0, 6, size.y - 8),
      handle,
    );
  }
}
