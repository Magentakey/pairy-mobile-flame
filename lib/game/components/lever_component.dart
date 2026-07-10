import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Tuas yang diaktifkan dengan menekan tombol HUD saat player berada
/// di dekatnya. Anchor.bottomCenter — titik spawn di Tiled = kaki lever.
class LeverComponent extends PositionComponent with CollisionCallbacks {
  LeverComponent({required super.position, this.onToggle})
    : super(size: Vector2(20, 24), anchor: Anchor.bottomCenter);

  final VoidCallback? onToggle;
  bool isOn = false;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  void activate() {
    isOn = !isOn;
    onToggle?.call();
  }

  @override
  void render(Canvas canvas) {
    // Local (0,0) = top-left bounding box (konvensi standar Flame),
    // berlaku sama untuk semua anchor.

    // Dudukan (alas)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.y * 0.5, size.x, size.y * 0.5),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF555577),
    );

    // Gagang — condong kiri (off) atau kanan (on)
    final baseX = size.x / 2;
    final baseY = size.y * 0.55;
    final topY = size.y * 0.1;
    final handleX = isOn ? size.x * 0.65 : size.x * 0.35;
    final handleColor = isOn
        ? const Color(0xFF34C77B)
        : const Color(0xFFE85C4A);

    canvas.drawLine(
      Offset(baseX, baseY),
      Offset(handleX, topY),
      Paint()
        ..color = handleColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(handleX, topY), 4, Paint()..color = handleColor);
  }
}
