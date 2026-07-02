import 'dart:math' show min;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import 'gate_component.dart';
import 'ground_component.dart';

/// Fairy bisa di-drag langsung dengan jari.
///
/// Behavior:
/// - Drag → fairy ikut jari secara instan (tidak lag, tidak lerp).
/// - Lepas → fairy TETAP di posisi terakhir drag (tidak snap ke home).
/// - Collision: menembus Player dan Fountain (trigger), tapi SOLID
///   terhadap GroundComponent, GateComponent (tertutup), dan FairyComponent lain.
/// - Aktivasi fountain: ditangani oleh FountainComponent via Flame collision
///   callback (bukan dari FairyComponent) → fairy tidak perlu menghilang.
class FairyComponent extends PositionComponent
    with DragCallbacks, CollisionCallbacks {
  FairyComponent({required super.position, required this.color})
      : super(size: Vector2.all(20), anchor: Anchor.center);

  final FairyColor color;

  // Posisi jari di world space — hanya diupdate onDragUpdate,
  // TIDAK pernah direset oleh collision sehingga fairy selalu menuju jari.
  Vector2 _fingerWorldPos = Vector2.zero();
  bool _isDragging = false;

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
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
    // Fairy tetap di posisi sekarang — tidak kembali ke home.
    // Fountain mendeteksi overlap via onCollisionStart/End sendiri.
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isDragging) {
      // Langsung ikut jari, tidak ada lerp
      position.setFrom(_fingerWorldPos);
    }
    // Selalu resolve solids — baik saat drag maupun diam
    // (misalnya gate menutup saat fairy ada di dalam gate)
    _resolveSolids();
  }

  /// Dorong fairy keluar dari solid. Fountain dan Player sengaja tidak ada
  /// di sini — fairy bisa menembus keduanya.
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
    // _fingerWorldPos TIDAK diupdate → fairy terus mencoba
    // kembali ke jari, menciptakan efek "terblokir tembok" yang natural.
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
