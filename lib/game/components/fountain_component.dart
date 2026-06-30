import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';

/// Fountain menyala saat menerima fairy berwarna sama (PRD 6.7),
/// lalu memanggil [onActivated] sekali — biasanya untuk membuka gate.
class FountainComponent extends PositionComponent with CollisionCallbacks {
  FountainComponent({
    required super.position,
    required this.requiredColor,
    this.onActivated,
  }) : super(size: Vector2(24, 30), anchor: Anchor.bottomCenter);

  final FairyColor requiredColor;
  final VoidCallback? onActivated;
  bool isActivated = false;

  @override
  Future<void> onLoad() async {
    // Passive — tidak solid, hanya area deteksi untuk fairy
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  void receiveFairy(FairyColor color) {
    if (isActivated || color != requiredColor) return;
    isActivated = true;
    onActivated?.call();
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final fillColor =
        isActivated ? requiredColor.displayColor : const Color(0xFF6B6B7A);

    // Basin fountain (mangkuk)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF44445C),
    );

    // Air/isi fountain — warna sesuai requiredColor, terang jika aktif
    final waterRect = Rect.fromLTWH(
      3, size.y * 0.25, size.x - 6, size.y * 0.65,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(3)),
      Paint()..color = fillColor.withValues(alpha: isActivated ? 1.0 : 0.4),
    );

    // Border outline warna target — selalu kelihatan walau belum aktif
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(3)),
      Paint()
        ..color = requiredColor.displayColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
