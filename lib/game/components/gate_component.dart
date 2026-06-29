import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Gerbang solid yang bisa dibuka/ditutup oleh LeverComponent.
/// Ketika tertutup → solid (player tidak bisa melewati).
/// Ketika terbuka  → transparan, player bisa lewat.
class GateComponent extends PositionComponent with CollisionCallbacks {
  GateComponent({required super.position, required super.size});

  bool isOpenState = false;

  void open()  => isOpenState = true;
  void close() => isOpenState = false;

  /// Dipanggil oleh LeverComponent: isOn=true → buka, isOn=false → tutup.
  void toggle(bool isOn) => isOn ? open() : close();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void render(Canvas canvas) {
    if (isOpenState) return; // terbuka = tidak terlihat, tidak solid

    // Gerbang tertutup — bar ungu bergaris
    final rect = size.toRect();
    canvas.drawRect(rect, Paint()..color = const Color(0xFF6A3FA0));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF9B6FD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Garis dekorasi horizontal
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
