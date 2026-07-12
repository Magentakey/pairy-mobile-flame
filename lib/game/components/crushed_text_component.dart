import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Text sekali-pakai yang nongol sesaat di titik brick hancur (mis.
/// ketiban Gate yang menutup), melayang naik tipis sambil fade-out, lalu
/// self-destruct ([removeFromParent]) begitu durasinya habis. Murni
/// visual, tidak ada hitbox/collision sama sekali.
class CrushedTextComponent extends TextComponent {
  CrushedTextComponent({required super.position, String text = 'Crushed'})
    : super(
        text: text,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFF5252),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  static const double _duration = 0.9;
  static const double _riseSpeed = 12;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.y -= _riseSpeed * dt;

    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    final opacity = 1.0 - t;
    textRenderer = TextPaint(
      style: TextStyle(
        color: const Color(0xFFFF5252).withValues(alpha: opacity),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );

    if (_elapsed >= _duration) removeFromParent();
  }
}
