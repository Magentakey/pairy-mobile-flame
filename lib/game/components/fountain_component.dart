import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import 'fairy_component.dart';

/// Fountain aktif saat fairy berwarna sama berada di atasnya.
/// Ketika fairy masuk → onActivate (gate buka).
/// Ketika fairy keluar → onDeactivate (gate tutup).
/// Bisa on/off berkali-kali.
class FountainComponent extends PositionComponent with CollisionCallbacks {
  FountainComponent({
    required super.position,
    required this.requiredColor,
    this.onActivate,
    this.onDeactivate,
  }) : super(size: Vector2(24, 30), anchor: Anchor.bottomCenter);

  final FairyColor requiredColor;
  final VoidCallback? onActivate;
  final VoidCallback? onDeactivate;
  bool isActivated = false;

  // Hitung berapa fairy warna cocok yang sedang overlap
  // (antisipasi > 1 fairy warna sama di level)
  int _matchingCount = 0;

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
    if (other is FairyComponent && other.color == requiredColor) {
      _matchingCount++;
      if (!isActivated) {
        isActivated = true;
        onActivate?.call();
      }
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is FairyComponent && other.color == requiredColor) {
      _matchingCount = (_matchingCount - 1).clamp(0, 99);
      if (_matchingCount == 0 && isActivated) {
        isActivated = false;
        onDeactivate?.call();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final baseColor = requiredColor.displayColor;

    // Badan fountain
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF44445C),
    );

    // Air — warna target selalu kelihatan (guide untuk player)
    final waterRect = Rect.fromLTWH(3, size.y * 0.25, size.x - 6, size.y * 0.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(3)),
      Paint()..color = baseColor.withValues(alpha: isActivated ? 1.0 : 0.25),
    );
    // Border warna target — selalu tampil sebagai hint
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(3)),
      Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
