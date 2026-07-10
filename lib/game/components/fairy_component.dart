import 'dart:math' show min;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import '../pairy_game.dart';
import 'gate_component.dart';
import 'ground_component.dart';

class FairyComponent extends PositionComponent
    with DragCallbacks, CollisionCallbacks, HasGameReference<PairyGame> {
  FairyComponent({required super.position, required this.color})
    : super(size: Vector2.all(20), anchor: Anchor.center);

  final FairyColor color;

  Vector2 _fingerWorldPos = Vector2.zero();
  bool _isDragging = false;

  // Track gate state tiap frame untuk deteksi crush
  final Map<GateComponent, bool> _gateWasOpen = {};

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
    // Batas map sekarang ditangani oleh blok collision fisik (GroundComponent),
    // jadi tidak perlu clamp manual ke ukuran map di sini lagi.
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // ── Cek gate crush SEBELUM movement ─────────────────────────────
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is GateComponent) {
          final wasOpen = _gateWasOpen[child] ?? true;
          if (!child.isOpenState && wasOpen && _isInsideGate(child)) {
            _gateWasOpen[child] = false;
            removeFromParent();
            game.playerDied('Fairy Crushed by Gate');
            return;
          }
          _gateWasOpen[child] = child.isOpenState;
        }
      }
    }

    // ── Movement ────────────────────────────────────────────────────
    if (_isDragging) {
      const maxSpeed = 600.0;
      const stepSize = 8.0;
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

  bool _isInsideGate(GateComponent gate) {
    final tl =
        gate.position -
        Vector2(gate.size.x * gate.anchor.x, gate.size.y * gate.anchor.y);
    return position.x > tl.x &&
        position.x < tl.x + gate.size.x &&
        position.y > tl.y &&
        position.y < tl.y + gate.size.y;
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
    final tl =
        other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
    final r = size.x / 2;

    final overlapR = (position.x + r) - tl.x;
    final overlapL = (tl.x + other.size.x) - (position.x - r);
    final overlapB = (position.y + r) - tl.y;
    final overlapT = (tl.y + other.size.y) - (position.y - r);

    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0)
      return;

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

  @override
  void render(Canvas canvas) {
    final radius = size.x / 2;
    final center = Offset(radius, radius);
    final glowRadius = radius * 2.5;

    final dragBoost = _isDragging ? 1.15 : 1.0;

    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.9),
              color.displayColor.withValues(alpha: 0.7),
              color.displayColor.withValues(alpha: 0.25),
              color.displayColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.25, 0.6, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: glowRadius * dragBoost),
          );

    canvas.drawCircle(center, glowRadius * dragBoost, glowPaint);
  }
}
