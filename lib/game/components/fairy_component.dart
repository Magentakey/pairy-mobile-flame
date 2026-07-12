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
        // Priority tinggi eksplisit — supaya fairy SELALU render paling
        // atas dibanding komponen level lain (fountain, gate, platform,
        // ground, dst), apa pun urutan object id-nya di Tiled. Tanpa ini,
        // urutan render cuma ngikutin urutan add() (= urutan object di
        // layer Spawnpoints), jadi kalau id Fountain < id Fairy, Fountain
        // ke-add duluan dan bisa nutupin fairy pas overlap.
        priority: 100,
      );

  final FairyColor color;

  Vector2 _fingerWorldPos = Vector2.zero();
  bool _isDragging = false;

  // Posisi kamera (cam.viewfinder.position) di frame sebelumnya, dipakai
  // SELAMA dragging untuk kompensasi pan kamera (lihat update()). Perlu
  // karena event drag (onDragUpdate) HANYA fired kalau jari BENERAN
  // bergerak di layar -- kalau jari diam tapi kamera ikut geser (mis.
  // cam.follow(player) pas player jalan), tidak ada event baru sama
  // sekali, jadi _fingerWorldPos jadi stale/ketinggalan padahal titik di
  // layar yang ditunjuk jari itu sekarang berkorespondensi ke posisi
  // dunia yang berbeda.
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
      // Kompensasi pan kamera: kalau kamera geser (mis. ngikutin player
      // yang jalan) SEMENTARA jari diam di layar, titik dunia yang
      // ditunjuk jari itu ikut geser sebesar pergeseran kamera juga.
      // Tanpa ini, _fingerWorldPos cuma ke-update pas ada event drag
      // baru (jari beneran gerak), jadi fairy keliatan "netep" nggak
      // ngikutin walau jari masih di posisi layar yang sama.
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

    // ── Cek crush oleh moving platform SETELAH resolve ──────────────
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

  /// Sama seperti [_pushOutOf], tapi khusus [MovingPlatformComponent].
  /// Murni efek dorong (solid) — fairy TIDAK ikut menumpang gerak
  /// horizontal platform saat nempel di atasnya. Dorongan dari sisi
  /// samping platform (ujung kiri/kanan saat bergerak horizontal) tetap
  /// jalan lewat cabang overlapR/overlapL di bawah, karena itu murni efek
  /// collision push, bukan "mengikuti" platform.
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

  /// Sama seperti [_pushOutOfPlatform], tapi khusus [StoneBrickComponent].
  /// Murni efek dorong (solid) — fairy TIDAK ikut menumpang gerak brick
  /// (baik pas brick jatuh maupun didorong), sama seperti fairy tidak
  /// ikut menumpang moving platform.
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

  /// Deteksi fairy "kejepit" oleh moving platform: fairy masih overlap
  /// cukup dalam (melebihi threshold di kedua sumbu) dengan solid lain
  /// (ground/gate tertutup/platform lain) SAAT bersentuhan dengan moving
  /// platform yang sedang bergerak. Konsisten dengan
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

  /// Overlap dangkal (boleh dengan buffer toleransi) — dipakai sekadar
  /// untuk tes "apakah fairy sedang bersentuhan dengan platform ini",
  /// BUKAN untuk tes kejepit (lihat [_deepOverlap]).
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
