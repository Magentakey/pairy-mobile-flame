import 'dart:math' show min;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import 'fountain_component.dart';
import 'gate_component.dart';
import 'ground_component.dart';

/// Fairy bisa di-drag langsung pakai jari (PRD 6.6).
///
/// Desain drag:
/// - Posisi langsung mengikuti jari (_fingerWorldPos), TANPA lerp,
///   supaya tidak ada lag dan tidak teleport.
/// - Collision mendorong posisi keluar dari solid, tapi TIDAK mengubah
///   _fingerWorldPos — frame berikutnya fairy mencoba balik ke jari lagi,
///   hasilnya terasa "terblokir tembok" secara natural.
/// - Saat dilepas: lerp halus kembali ke posisi awal (home).
class FairyComponent extends PositionComponent
    with DragCallbacks, CollisionCallbacks {
  FairyComponent({required super.position, required this.color})
      : super(size: Vector2.all(20), anchor: Anchor.center);

  final FairyColor color;
  late final Vector2 _homePosition = position.clone();

  // Posisi jari di world space — tidak pernah direset oleh collision
  Vector2 _fingerWorldPos = Vector2.zero();
  bool _isDragging = false;
  bool _activated = false;

  final Set<FountainComponent> _overlappingFountains = {};

  @override
  Future<void> onLoad() async {
    _fingerWorldPos.setFrom(position);
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_activated) return;
    _isDragging = true;
    _fingerWorldPos.setFrom(position);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_isDragging) return;
    _fingerWorldPos += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;

    // Cek fountain via callback set
    FountainComponent? target =
        _overlappingFountains.isNotEmpty ? _overlappingFountains.first : null;

    // Fallback: direct check jika callback belum fire di frame ini
    if (target == null && parent != null) {
      for (final child in parent!.children) {
        if (child is FountainComponent && _isOverlappingFountain(child)) {
          target = child;
          break;
        }
      }
    }

    if (target != null) {
      target.receiveFairy(color);
      if (target.isActivated) {
        _activated = true;
        removeFromParent();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_activated) return;

    if (_isDragging) {
      // Langsung ikut jari — tidak ada lerp supaya tidak lag/teleport
      position.setFrom(_fingerWorldPos);
      // Push keluar dari solid; _fingerWorldPos TIDAK diubah
      _resolveSolids();
    } else {
      // Kembali ke home dengan lerp halus
      final diff = _homePosition - position;
      if (diff.length < 0.5) {
        position.setFrom(_homePosition);
      } else {
        position += diff * (10.0 * dt).clamp(0.0, 1.0);
      }
    }
  }

  void _resolveSolids() {
    if (parent == null) return;
    for (final child in parent!.children) {
      if (child is GroundComponent) {
        _pushOutOf(child);
      } else if (child is GateComponent && !child.isOpenState) {
        _pushOutOf(child);
      } else if (child is FairyComponent && child != this) {
        _pushAwayFrom(child);
      }
    }
  }

  void _pushOutOf(PositionComponent other) {
    final topLeft = other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
    final r = size.x / 2;

    final overlapR = (position.x + r) - topLeft.x;
    final overlapL = (topLeft.x + other.size.x) - (position.x - r);
    final overlapB = (position.y + r) - topLeft.y;
    final overlapT = (topLeft.y + other.size.y) - (position.y - r);

    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) return;

    final minX = min(overlapR, overlapL);
    final minY = min(overlapB, overlapT);

    if (minX < minY) {
      position.x += overlapR < overlapL ? -overlapR : overlapL;
    } else {
      position.y += overlapB < overlapT ? -overlapB : overlapT;
    }
  }

  void _pushAwayFrom(FairyComponent other) {
    final delta = position - other.position;
    final dist = delta.length;
    final minDist = size.x;
    if (dist >= minDist || dist == 0) return;
    position += (delta / dist) * ((minDist - dist) / 2);
  }

  bool _isOverlappingFountain(FountainComponent f) {
    final tl = f.position -
        Vector2(f.size.x * f.anchor.x, f.size.y * f.anchor.y);
    final r = size.x / 2;
    return position.x + r > tl.x &&
        position.x - r < tl.x + f.size.x &&
        position.y + r > tl.y &&
        position.y - r < tl.y + f.size.y;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
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
    if (_activated) return;
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
      center, radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
