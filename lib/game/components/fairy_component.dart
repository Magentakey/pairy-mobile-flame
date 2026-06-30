import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import 'fountain_component.dart';

/// Fairy yang bisa di-drag langsung dengan jari (PRD 6.6).
///
/// Tidak collide dengan player (player tidak treat fairy sebagai solid,
/// dan fairy tidak treat player sebagai solid) — fairy hanya bereaksi
/// terhadap [FountainComponent] lain lewat Flame collision callbacks.
class FairyComponent extends PositionComponent
    with DragCallbacks, CollisionCallbacks {
  FairyComponent({required super.position, required this.color})
      : super(size: Vector2.all(20), anchor: Anchor.center);

  final FairyColor color;
  late final Vector2 _homePosition = position.clone();

  final Set<FountainComponent> _overlappingFountains = {};
  bool _isDragging = false;

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isDragging = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
    if (_overlappingFountains.isNotEmpty) {
      _overlappingFountains.first.receiveFairy(color);
    } else {
      position = _homePosition.clone();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> pts, PositionComponent other) {
    super.onCollisionStart(pts, other);
    if (other is FountainComponent) _overlappingFountains.add(other);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is FountainComponent) _overlappingFountains.remove(other);
  }

  @override
  void render(Canvas canvas) {
    final radius = size.x / 2;
    final center = Offset(radius, radius);

    // Glow lembut saat sedang di-drag
    if (_isDragging) {
      canvas.drawCircle(
        center,
        radius + 4,
        Paint()..color = color.displayColor.withValues(alpha: 0.3),
      );
    }

    canvas.drawCircle(center, radius, Paint()..color = color.displayColor);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
