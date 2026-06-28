import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import 'fountain_component.dart';

/// A floating, draggable fairy (PRD 6.6).
///
/// Per the PRD the fairy has **no collision with the player** — it can be
/// dragged right through them — but **does** collide with other fairies,
/// so two fairies can't be stacked on the same spot. Dropping a fairy on
/// a matching [FountainComponent] activates it; otherwise it snaps back
/// to its starting position.
class FairyComponent extends PositionComponent
    with DragCallbacks, CollisionCallbacks {
  FairyComponent({required super.position, required this.color})
      : super(size: Vector2.all(22), anchor: Anchor.center);

  final FairyColor color;
  late final Vector2 _homePosition = position.clone();

  /// Fountains currently overlapping this fairy, tracked via Flame's
  /// collision callbacks rather than manual rect math.
  final Set<FountainComponent> _overlappingFountains = {};

  @override
  Future<void> onLoad() async {
    // Active because the fairy moves every frame while being dragged.
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_overlappingFountains.isNotEmpty) {
      _overlappingFountains.first.receiveFairy(color);
    } else {
      // Replace with your own puzzle rules (e.g. free placement) as
      // the design evolves — snapping home keeps the prototype simple.
      position = _homePosition.clone();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is FountainComponent) {
      _overlappingFountains.add(other);
    }
    // Note: deliberately NOT handling FairyComponent here beyond the
    // hitbox itself — the collision still blocks two fairies from
    // occupying the same space (PRD: "Fairy memiliki collision dengan
    // fairy lain"), it just doesn't need a custom reaction yet.
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is FountainComponent) {
      _overlappingFountains.remove(other);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()..color = color.displayColor,
    );
  }
}
