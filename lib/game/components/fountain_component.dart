import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/fairy_color.dart';
import 'fairy_component.dart';
import 'gate_component.dart';

/// Fountain aktif saat fairy berwarna sama berada di atasnya.
/// Beda dengan lever, fountain TIDAK memaksa gate ke state tertentu:
/// - Fairy pertama masuk → gate di-toggle (flip apa adanya).
/// - Fairy terakhir keluar → gate di-restore ke state SEBELUM
///   toggle tadi (snapshot), bukan sekadar toggle lagi. Ini penting
///   untuk kasus > 1 fairy warna sama overlap gantian di fountain
///   yang sama (lihat _matchingCount).
///
/// NOTE: Overlap detection dilakukan MANUAL (AABB clamp) di [update],
/// bukan lewat Flame CollisionCallbacks. Ini disengaja: kombinasi
/// CircleHitbox (fairy) vs RectangleHitbox (fountain) punya edge case
/// di engine Flame — kalau titik pusat fairy persis segaris dengan
/// sumbu simetri fountain (misal fairy pas di tengah horizontal),
/// proyeksi SAT jadi degenerate dan onCollisionStart bisa gagal
/// terpanggil sama sekali. Manual AABB check di bawah ini tidak
/// punya masalah tsb karena tidak bergantung pada arah normal.
class FountainComponent extends PositionComponent {
  FountainComponent({
    required super.position,
    required this.requiredColor,
    this.targetGate,
  }) : super(size: Vector2(24, 30), anchor: Anchor.bottomCenter);

  final FairyColor requiredColor;
  final GateComponent? targetGate;
  bool isActivated = false;

  int _matchingCount = 0;
  bool? _gateStateBeforeActivate;
  final Set<FairyComponent> _overlapping = {};

  @override
  void update(double dt) {
    super.update(dt);
    if (parent == null) return;

    final stillOverlapping = <FairyComponent>{};

    for (final child in parent!.children) {
      if (child is FairyComponent && _circleOverlapsRect(child)) {
        stillOverlapping.add(child);
      }
    }

    for (final fairy in stillOverlapping) {
      if (!_overlapping.contains(fairy)) {
        _onFairyEnter(fairy);
      }
    }

    for (final fairy in _overlapping) {
      if (!stillOverlapping.contains(fairy)) {
        _onFairyExit(fairy);
      }
    }

    _overlapping
      ..clear()
      ..addAll(stillOverlapping);
  }

  bool _circleOverlapsRect(FairyComponent fairy) {
    final tl = position - Vector2(size.x * anchor.x, size.y * anchor.y);
    final br = tl + size;

    final closestX = fairy.position.x.clamp(tl.x, br.x);
    final closestY = fairy.position.y.clamp(tl.y, br.y);

    final dx = fairy.position.x - closestX;
    final dy = fairy.position.y - closestY;
    final r = fairy.size.x / 2;

    return (dx * dx + dy * dy) <= (r * r);
  }

  void _onFairyEnter(FairyComponent fairy) {
    if (fairy.color != requiredColor) return;
    _matchingCount++;
    if (!isActivated) {
      isActivated = true;
      _gateStateBeforeActivate = targetGate?.isOpenState;
      targetGate?.toggleState();
    }
  }

  void _onFairyExit(FairyComponent fairy) {
    if (fairy.color != requiredColor) return;
    _matchingCount = (_matchingCount - 1).clamp(0, 99);
    if (_matchingCount == 0 && isActivated) {
      isActivated = false;
      final before = _gateStateBeforeActivate;
      if (before != null && targetGate != null) {
        before ? targetGate!.open() : targetGate!.close();
      }
      _gateStateBeforeActivate = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final baseColor = requiredColor.displayColor;

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF44445C),
    );

    final waterRect = Rect.fromLTWH(
      3,
      size.y * 0.25,
      size.x - 6,
      size.y * 0.65,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(3)),
      Paint()..color = baseColor.withValues(alpha: isActivated ? 1.0 : 0.25),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(3)),
      Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
