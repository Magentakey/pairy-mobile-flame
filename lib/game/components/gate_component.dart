import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A gate that blocks the path until opened by a [LeverComponent] or a
/// [FountainComponent] (PRD 6.5: "Gate dikontrol lever atau fairy
/// mechanic").
class GateComponent extends PositionComponent with CollisionCallbacks {
  GateComponent({required super.position, required super.size});

  bool isOpenState = false;
  late final RectangleHitbox _hitbox;

  @override
  Future<void> onLoad() async {
    _hitbox = RectangleHitbox(collisionType: CollisionType.passive);
    add(_hitbox);
  }

  void open() {
    isOpenState = true;
    _hitbox.collisionType = CollisionType.inactive;
  }

  void close() {
    isOpenState = false;
    _hitbox.collisionType = CollisionType.passive;
  }

  /// Convenient signature for wiring directly into
  /// `LeverComponent(onToggle: gate.toggle)`.
  void toggle(bool isOn) => isOn ? open() : close();

  @override
  void render(Canvas canvas) {
    if (isOpenState) return; // swap for a slide/fade effect once art lands
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFFB71C1C));
  }
}
