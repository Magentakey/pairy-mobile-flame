import 'dart:math' show min;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import 'gate_component.dart';
import 'ground_component.dart';

class FairyComponent extends PositionComponent
    with DragCallbacks, CollisionCallbacks {
  FairyComponent({required super.position, required this.color})
      : super(size: Vector2.all(20), anchor: Anchor.center);

  final FairyColor color;

  Vector2 _fingerWorldPos = Vector2.zero();
  bool _isDragging = false;

  // Batas map — sesuaikan jika ukuran map berubah
  static const double _mapW = 648.0;
  static const double _mapH = 360.0;

  @override
  Future<void> onLoad() async {
    _fingerWorldPos.setFrom(position);
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isDragging = true;
    _fingerWorldPos.setFrom(position);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_isDragging) return;
    _fingerWorldPos += event.localDelta;
    // Clamp jari ke batas map — cegah fairy drift off-screen
    _fingerWorldPos.x = _fingerWorldPos.x.clamp(0, _mapW);
    _fingerWorldPos.y = _fingerWorldPos.y.clamp(0, _mapH);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isDragging) {
      // Gerak menuju jari dengan kecepatan maksimum + sub-step collision
      // → tidak bisa teleport menembus dinding/tile
      const maxSpeed = 600.0; // px/s
      const stepSize = 8.0;   // lebih kecil dari tile (18px) → anti-tunneling

      final diff = _fingerWorldPos - position;
      final dist = diff.length;

      if (dist > 0.5) {
        var remaining = (maxSpeed * dt).clamp(0.0, dist);
        final dir = diff / dist;

        while (remaining > 0) {
          final step = remaining.clamp(0.0, stepSize);
          position += dir * step;
          _resolveSolids();
          remaining -= step;
        }
      }
    } else {
      _resolveSolids();
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
    final tl = other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
    final r = size.x / 2;

    final overlapR = (position.x + r) - tl.x;
    final overlapL = (tl.x + other.size.x) - (position.x - r);
    final overlapB = (position.y + r) - tl.y;
    final overlapT = (tl.y + other.size.y) - (position.y - r);

    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) return;

    final minX = min(overlapR, overlapL);
    final minY = min(overlapB, overlapT);

    if (minX < minY) {
      position.x += overlapR < overlapL ? -overlapR : overlapL;
    } else {
      position.y += overlapB < overlapT ? -overlapB : overlapT;
    }
    // _fingerWorldPos tidak diupdate → jika tembok di jalan,
    // fairy berhenti di tepi tembok dan terus mengarah ke jari.
  }

  void _pushAwayFrom(FairyComponent other) {
    final delta = position - other.position;
    final dist = delta.length;
    final minDist = size.x;
    if (dist >= minDist || dist == 0) return;
    position += (delta / dist) * ((minDist - dist) / 2);
  }

  @override
  void render(Canvas canvas) {
    final radius = size.x / 2;
    final center = Offset(radius, radius);
    if (_isDragging) {
      canvas.drawCircle(
        center, radius + 4,
        Paint()..color = color.displayColor.withValues(alpha: 0.3),
      );
    }
    canvas.drawCircle(center, radius, Paint()..color = color.displayColor);
    canvas.drawCircle(center, radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }
}
