import 'dart:math' show min, max;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import 'fountain_component.dart';
import 'gate_component.dart';
import 'ground_component.dart';

/// Fairy yang bisa di-drag dengan jari (PRD 6.6).
///
/// Gerakan di-smooth pakai lerp (bukan langsung ikut jari mentah-mentah)
/// supaya terasa lebih halus. Fairy collide dengan tile solid (Ground,
/// Gate tertutup) dan fairy lain, TAPI tetap tembus terhadap player —
/// player tidak pernah dimasukkan ke pengecekan collision di sini.
class FairyComponent extends PositionComponent
    with DragCallbacks, CollisionCallbacks {
  FairyComponent({required super.position, required this.color})
      : super(size: Vector2.all(20), anchor: Anchor.center);

  final FairyColor color;
  late final Vector2 _homePosition = position.clone();

  Vector2 _targetPosition = Vector2.zero();
  static const double followSpeed = 16; // makin besar = makin responsif

  final Set<FountainComponent> _overlappingFountains = {};
  bool _isDragging = false;

  @override
  Future<void> onLoad() async {
    _targetPosition.setFrom(position);
    // Active hitbox — dipakai khusus untuk deteksi overlap dengan Fountain
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
    _targetPosition += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
    if (_overlappingFountains.isNotEmpty) {
      _overlappingFountains.first.receiveFairy(color);
      _targetPosition.setFrom(position);
    } else {
      _targetPosition.setFrom(_homePosition);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Gerakan halus menuju target (saat drag) atau kembali ke home
    final t = (followSpeed * dt).clamp(0.0, 1.0);
    position.setFrom(position + (_targetPosition - position) * t);

    _resolveSolids();
  }

  void _resolveSolids() {
    if (parent == null) return;
    for (final child in parent!.children) {
      if (child is GroundComponent) {
        _pushOutOfRect(child.position, child.size, child.anchor);
      } else if (child is GateComponent && !child.isOpenState) {
        _pushOutOfRect(child.position, child.size, child.anchor);
      } else if (child is FairyComponent && child != this) {
        _pushAwayFromFairy(child);
      }
      // PlayerComponent sengaja TIDAK dicek di sini — fairy selalu tembus player.
    }
  }

  /// Dorong fairy keluar dari rect solid manapun (anchor-aware).
  void _pushOutOfRect(Vector2 otherPos, Vector2 otherSize, Anchor otherAnchor) {
    final topLeft = otherPos - Vector2(
      otherSize.x * otherAnchor.x,
      otherSize.y * otherAnchor.y,
    );
    final halfSize = size.x / 2;

    final left   = position.x - halfSize;
    final right  = position.x + halfSize;
    final top    = position.y - halfSize;
    final bottom = position.y + halfSize;

    final oLeft   = topLeft.x;
    final oRight  = topLeft.x + otherSize.x;
    final oTop    = topLeft.y;
    final oBottom = topLeft.y + otherSize.y;

    final overlapX = min(right, oRight) - max(left, oLeft);
    final overlapY = min(bottom, oBottom) - max(top, oTop);
    if (overlapX <= 0 || overlapY <= 0) return;

    if (overlapX < overlapY) {
      position.x += (position.x < (oLeft + oRight) / 2) ? -overlapX : overlapX;
    } else {
      position.y += (position.y < (oTop + oBottom) / 2) ? -overlapY : overlapY;
    }
    _targetPosition.setFrom(position);
  }

  /// Dorong dua fairy saling menjauh kalau saling tumpang tindih.
  void _pushAwayFromFairy(FairyComponent other) {
    final delta = position - other.position;
    final dist  = delta.length;
    final minDist = (size.x / 2) + (other.size.x / 2);
    if (dist >= minDist || dist == 0) return;

    final pushDir = delta / dist;
    final overlap = minDist - dist;
    position += pushDir * (overlap / 2);
    _targetPosition.setFrom(position);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
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
