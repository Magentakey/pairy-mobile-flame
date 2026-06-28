import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A static solid block: floor, platform, wall, or staircase step.
///
/// Once a Tiled map is wired in (see `lib/game/level/level_loader.dart`),
/// ground geometry will come from the map's collision layer instead of
/// being hand-declared like in `PairyWorld.buildDemoLevel`.
class GroundComponent extends PositionComponent with CollisionCallbacks {
  GroundComponent({required super.position, required super.size});

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF757575));
  }
}
