import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';

class ExitDoorComponent extends PositionComponent with CollisionCallbacks {
  ExitDoorComponent({required super.position})
      : super(size: Vector2(26, 40), anchor: Anchor.topLeft);

  bool _showTooltip = false;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    _showTooltip = true;
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    _showTooltip = false;
  }

  @override
  void render(Canvas canvas) {
    // ── Pintu ─────────────────────────────────────────────────────
    final body = size.toRect();
    canvas.drawRect(body, Paint()..color = const Color(0xFFEEEEEE));
    canvas.drawRect(
      body,
      Paint()
        ..color = const Color(0xFF333355)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      Rect.fromLTWH(2, 2, size.x - 4, size.x - 4),
      3.14, 3.14, false,
      Paint()
        ..color = const Color(0xFF333355)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(size.x - 6, size.y * 0.65),
      2.5,
      Paint()..color = const Color(0xFFFFCC44),
    );

    // ── Tooltip (hanya saat player menyentuh pintu) ───────────────
    if (!_showTooltip) return;

    const tooltipText = '↑  Keluar';
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 9,
        fontWeight: FontWeight.bold,
        shadows: const [ui.Shadow(color: Color(0xFF000000), blurRadius: 4)],
      ))
      ..addText(tooltipText);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 60));

    canvas.drawParagraph(
      paragraph,
      Offset(size.x / 2 - paragraph.maxIntrinsicWidth / 2, -16),
    );
  }
}
