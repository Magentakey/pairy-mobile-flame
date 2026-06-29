import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// Tuas yang bisa diketuk untuk toggle gate.
/// Ketuk saat player berada di dekat/di atas lever.
class LeverComponent extends PositionComponent
    with TapCallbacks, CollisionCallbacks {
  LeverComponent({
    required super.position,
    this.onToggle,
  }) : super(size: Vector2(20, 24), anchor: Anchor.topLeft);

  final void Function(bool isOn)? onToggle;
  bool isOn = false;

  @override
  Future<void> onLoad() async {
    // Passive hitbox — player bisa berdiri di atasnya, tidak menghalangi
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void onTapDown(TapDownEvent event) {
    isOn = !isOn;
    onToggle?.call(isOn);
  }

  @override
  void render(Canvas canvas) {
    // Dudukan lever
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, size.y * 0.5, size.x - 4, size.y * 0.5),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF555577),
    );

    // Gagang lever (condong kiri=off, condong kanan=on)
    final handleX = isOn ? size.x * 0.65 : size.x * 0.35;
    canvas.drawLine(
      Offset(size.x / 2, size.y * 0.55),
      Offset(handleX, size.y * 0.1),
      Paint()
        ..color = isOn ? const Color(0xFF34C77B) : const Color(0xFFE85C4A)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Bola ujung gagang
    canvas.drawCircle(
      Offset(handleX, size.y * 0.1),
      4,
      Paint()..color = isOn ? const Color(0xFF34C77B) : const Color(0xFFE85C4A),
    );
  }
}
