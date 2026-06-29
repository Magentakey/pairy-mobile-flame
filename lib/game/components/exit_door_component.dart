import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

class ExitDoorComponent extends PositionComponent with CollisionCallbacks {
  ExitDoorComponent({required super.position})
      : super(size: Vector2(26, 40), anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));

    // Indikator "↑ Keluar" di atas pintu
    add(
      TextComponent(
        text: '↑  Keluar',
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
        anchor: Anchor.bottomCenter,
        position: Vector2(size.x / 2, -6),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    // Body pintu — putih dengan border gelap
    final body = size.toRect();
    canvas.drawRect(
      body,
      Paint()..color = const Color(0xFFEEEEEE),
    );
    canvas.drawRect(
      body,
      Paint()
        ..color = const Color(0xFF333355)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Lengkung atas pintu (dekorasi)
    final arcRect = Rect.fromLTWH(2, 2, size.x - 4, (size.x - 4));
    canvas.drawArc(
      arcRect,
      3.14,
      3.14,
      false,
      Paint()
        ..color = const Color(0xFF333355)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Kenop pintu kecil
    canvas.drawCircle(
      Offset(size.x - 6, size.y * 0.65),
      2.5,
      Paint()..color = const Color(0xFFFFCC44),
    );
  }
}
