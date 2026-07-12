import 'dart:math' show min, max;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import '../pairy_game.dart';
import 'gate_component.dart';
import 'ground_component.dart';
import 'moving_platform_component.dart';
import 'stone_brick_component.dart';

class FairyComponent extends PositionComponent
    with DragCallbacks, CollisionCallbacks, HasGameReference<PairyGame> {
  FairyComponent({required super.position, required this.color})
    : super(
        size: Vector2.all(20),
        anchor: Anchor.center,
        // Priority tinggi supaya fairy selalu render paling atas,
        // apa pun urutan object id-nya di Tiled.
        priority: 100,
      );

  final FairyColor color;

  Vector2 _fingerWorldPos = Vector2.zero();
  bool _isDragging = false;

  // Posisi kamera frame sebelumnya, untuk kompensasi pan kamera saat
  // dragging (onDragUpdate cuma fire kalau jari beneran gerak, jadi
  // perlu di-track manual kalau kamera geser sementara jari diam).
  final Vector2 _prevCamPosition = Vector2.zero();

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
    _prevCamPosition.setFrom(game.cam.viewfinder.position);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_isDragging) return;
    _fingerWorldPos += event.localDelta;
    // Batas map ditangani collision fisik (GroundComponent), tidak
    // perlu clamp manual di sini.
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Cek gate crush sebelum movement.
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

    // Movement
    if (_isDragging) {
      // Kompensasi pan kamera supaya fairy tetap ngikutin titik layar
      // yang ditunjuk jari, walau jari sendiri diam saat kamera geser.
      final camPos = game.cam.viewfinder.position;
      final camDelta = camPos - _prevCamPosition;
      if (camDelta.x != 0 || camDelta.y != 0) {
        _fingerWorldPos += camDelta;
      }
      _prevCamPosition.setFrom(camPos);

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

    // Cek crush oleh moving platform setelah resolve.
    _checkPlatformCrush();
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
      } else if (child is MovingPlatformComponent) {
        _pushOutOfPlatform(child);
      } else if (child is StoneBrickComponent) {
        _pushOutOfBrick(child);
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

  /// Sama seperti [_pushOutOf], khusus [MovingPlatformComponent].
  /// Murni efek dorong — fairy tidak ikut ter-carry gerak platform.
  void _pushOutOfPlatform(MovingPlatformComponent other) {
    final tl = _topLeft(other);
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

  /// Sama seperti [_pushOutOfPlatform], khusus [StoneBrickComponent].
  void _pushOutOfBrick(StoneBrickComponent other) {
    final tl = _topLeft(other);
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

  static const double _crushOverlapThreshold = 6.0;

  /// Deteksi fairy kejepit oleh moving platform (deep overlap dengan
  /// solid lain saat bersentuhan platform bergerak), konsisten dengan
  /// PlayerComponent._checkPlatformCrush.
  void _checkPlatformCrush() {
    if (parent == null) return;

    final touchingMovingPlatform = parent!.children.any(
      (c) =>
          (c is MovingPlatformComponent &&
              c.isMoving &&
              _shallowOverlap(c, buffer: 2)) ||
          (c is StoneBrickComponent && _shallowOverlap(c, buffer: 2)),
    );
    if (!touchingMovingPlatform) return;

    for (final child in parent!.children) {
      if (child is GroundComponent && _deepOverlap(child)) {
        removeFromParent();
        game.playerDied('Fairy Crushed by Platform');
        return;
      }
      if (child is GateComponent && !child.isOpenState && _deepOverlap(child)) {
        removeFromParent();
        game.playerDied('Fairy Crushed by Platform');
        return;
      }
      if (child is MovingPlatformComponent && _deepOverlap(child)) {
        removeFromParent();
        game.playerDied('Fairy Crushed by Platform');
        return;
      }
      if (child is StoneBrickComponent && _deepOverlap(child)) {
        removeFromParent();
        game.playerDied('Fairy Crushed by Platform');
        return;
      }
    }
  }

  /// Overlap dangkal (dengan buffer toleransi), untuk tes "bersentuhan",
  /// bukan tes kejepit (lihat [_deepOverlap]).
  bool _shallowOverlap(PositionComponent other, {double buffer = 0}) {
    final tl = _topLeft(other);
    final r = size.x / 2;
    return position.x + r > tl.x - buffer &&
        position.x - r < tl.x + other.size.x + buffer &&
        position.y + r > tl.y - buffer &&
        position.y - r < tl.y + other.size.y + buffer;
  }

  bool _deepOverlap(PositionComponent other) {
    final tl = _topLeft(other);
    final r = size.x / 2;

    final overlapX =
        min(position.x + r, tl.x + other.size.x) - max(position.x - r, tl.x);
    final overlapY =
        min(position.y + r, tl.y + other.size.y) - max(position.y - r, tl.y);

    return overlapX > _crushOverlapThreshold &&
        overlapY > _crushOverlapThreshold;
  }

  Vector2 _topLeft(PositionComponent other) {
    return other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
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
