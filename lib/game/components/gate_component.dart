import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Gerbang solid yang bisa dibuka/ditutup oleh LeverComponent atau
/// FountainComponent (lewat fairy yang aktivasi).
/// Anchor.bottomCenter — konsisten dengan Lever, Fountain, ExitDoor:
/// titik spawn di Tiled = posisi dasar (kaki) gerbang.
class GateComponent extends PositionComponent with CollisionCallbacks {
  GateComponent({required super.position, required super.size})
      : super(anchor: Anchor.bottomCenter);

  bool isOpenState = false;

  void open()  => isOpenState = true;
  void close() => isOpenState = false;
  void toggle(bool isOn) => isOn ? open() : close();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void render(Canvas canvas) {
    if (isOpenState) return;

    final rect = size.toRect();
    canvas.drawRect(rect, Paint()..color = const Color(0xFF6A3FA0));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF9B6FD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final stripeCount = (size.y / 10).floor();
    for (int i = 1; i < stripeCount; i++) {
      final y = i * 10.0;
      canvas.drawLine(
        Offset(2, y),
        Offset(size.x - 2, y),
        Paint()
          ..color = const Color(0xFF9B6FD4).withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
  }
}
