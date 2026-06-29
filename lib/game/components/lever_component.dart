import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Tuas yang diaktifkan dengan menekan ↑ saat player berada di dekatnya.
/// Sama seperti ExitDoor — proximity-based, bukan tap langsung.
class LeverComponent extends PositionComponent with CollisionCallbacks {
  LeverComponent({
    required super.position,
    this.onToggle,
  }) : super(size: Vector2(20, 24), anchor: Anchor.bottomCenter);

  final void Function(bool isOn)? onToggle;
  bool isOn = false;
  bool _showTooltip = false;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  /// Dipanggil oleh PlayerComponent saat ↑ ditekan di dekat lever.
  void activate() {
    isOn = !isOn;
    onToggle?.call(isOn);
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
    // ── Dudukan lever ──────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-size.x / 2, size.y * 0.5, size.x, size.y * 0.5),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF555577),
    );

    // ── Gagang lever ───────────────────────────────────────────────
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

    // ── Tooltip ↑ Aktif ────────────────────────────────────────────
    if (!_showTooltip) return;
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 9,
        fontWeight: FontWeight.bold,
        shadows: const [ui.Shadow(color: Color(0xFF000000), blurRadius: 4)],
      ))
      ..addText('↑  Aktif');
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 50));
    canvas.drawParagraph(para, Offset(-para.maxIntrinsicWidth / 2, -14));
  }
}
