import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class LeverComponent extends PositionComponent with CollisionCallbacks {
  LeverComponent({
    required super.position,
    this.onToggle,
  }) : super(size: Vector2(20, 24), anchor: Anchor.bottomCenter);

  final void Function(bool isOn)? onToggle;
  bool isOn = false;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  void activate() {
    isOn = !isOn;
    onToggle?.call(isOn);
  }

  @override
  void render(Canvas canvas) {
    // Dudukan
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-size.x / 2, size.y * 0.5, size.x, size.y * 0.5),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF555577),
    );

    // Gagang — condong kanan=on, kiri=off
    final handleX = isOn ? size.x * 0.15 : -size.x * 0.15;
    canvas.drawLine(
      Offset(0, size.y * 0.55),
      Offset(handleX, size.y * 0.1),
      Paint()
        ..color = isOn ? const Color(0xFF34C77B) : const Color(0xFFE85C4A)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(handleX, size.y * 0.1),
      4,
      Paint()..color = isOn ? const Color(0xFF34C77B) : const Color(0xFFE85C4A),
    );
  }
}
