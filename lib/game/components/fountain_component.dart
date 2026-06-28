import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';

/// A fountain lights up when it receives a fairy of the matching color
/// (PRD 6.7), then fires [onActivated] once — e.g. to open a connected
/// gate or unlock another puzzle object.
class FountainComponent extends PositionComponent with CollisionCallbacks {
  FountainComponent({
    required super.position,
    required this.requiredColor,
    this.onActivated,
  }) : super(size: Vector2(24, 30));

  final FairyColor requiredColor;
  final VoidCallback? onActivated;
  bool isActivated = false;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  void receiveFairy(FairyColor color) {
    if (isActivated || color != requiredColor) return;
    isActivated = true;
    onActivated?.call();
  }

  @override
  void render(Canvas canvas) {
    final color =
        isActivated ? requiredColor.displayColor : const Color(0xFFBDBDBD);
    canvas.drawRect(size.toRect(), Paint()..color = color);
  }
}
