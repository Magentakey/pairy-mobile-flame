import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/sprite.dart';

import 'player_component.dart';

class ExitDoorComponent extends PositionComponent with CollisionCallbacks {
  ExitDoorComponent({required super.position})
    : super(size: Vector2(26, 40), anchor: Anchor.bottomCenter);

  bool _showTooltip = false;
  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
    _sprite = await Sprite.load('exit_gate/exit_door.png');
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! PlayerComponent) return;
    _showTooltip = true;
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is! PlayerComponent) return;
    _showTooltip = false;
  }

  @override
  void render(Canvas canvas) {
    // Dengan Anchor.bottomCenter, (0,0) render = pojok kiri atas component
    _sprite?.render(
      canvas,
      size: size,
    ); // ← ganti semua drawRect/drawArc/drawCircle di atas dengan ini

    if (!_showTooltip) return;

    final pb =
        ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
          ..pushStyle(
            ui.TextStyle(
              color: const Color(0xFFFFFFFF),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              shadows: const [
                ui.Shadow(color: Color(0xFF000000), blurRadius: 4),
              ],
            ),
          )
          ..addText('↑  Keluar');
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 60));
    canvas.drawParagraph(
      para,
      Offset(size.x / 2 - para.maxIntrinsicWidth / 2, -14),
    );
  }
}
