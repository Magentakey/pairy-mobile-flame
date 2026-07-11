import 'dart:math' show min, max;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../pairy_game.dart';
import 'gate_component.dart';
import 'moving_platform_component.dart';

/// Balok batu solid yang:
/// - Kena gravitasi persis seperti player (bisa jatuh kalau didorong
///   dari tepi/tidak ada pijakan lagi di bawahnya).
/// - Bisa didorong player secara horizontal, HALUS/KONTINU (bukan snap
///   per-tile ala Sokoban klasik) — lihat [tryPush], dipanggil dari
///   PlayerComponent saat player nabrak brick ini secara horizontal.
/// - Bisa jadi pijakan: player (atau brick lain) bisa berdiri di atasnya,
///   dan ikut ter-carry kalau brick ini bergerak (jatuh/didorong/numpang
///   di moving platform) — lewat [frameDelta], persis seperti
///   MovingPlatformComponent.frameDelta.
/// - Bisa dipakai buat men-trigger [ButtonComponent] sebagai pengganti
///   player (ButtonComponent yang mendeteksi ini langsung, lihat
///   button_component.dart).
///
/// Resolve collision-nya SENGAJA ditulis manual (bukan lewat Flame
/// CollisionCallbacks), konsisten dengan pendekatan PlayerComponent —
/// supaya perilakunya predictable & gampang di-tune bareng physics
/// player yang sudah ada. Anchor.topLeft, size default 1 tile (18x18),
/// bisa dikustomisasi lewat width/height object Tiled.
class StoneBrickComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PairyGame> {
  StoneBrickComponent({required super.position, Vector2? size})
    : super(size: size ?? Vector2(18, 18), anchor: Anchor.topLeft);

  static const double gravity = 700;
  static const double maxDt = 1 / 30;

  final Vector2 velocity = Vector2.zero();
  bool isOnGround = false;

  /// Perpindahan brick pada frame INI — dipakai PlayerComponent (atau
  /// StoneBrickComponent lain) buat carry saat berdiri/napel di atasnya,
  /// persis seperti MovingPlatformComponent.frameDelta.
  final Vector2 frameDelta = Vector2.zero();

  final Vector2 _prevFramePosition = Vector2.zero();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
    _prevFramePosition.setFrom(position);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (parent == null) return;
    final safeDt = dt.clamp(0.0, maxDt);

    _prevFramePosition.setFrom(position);

    velocity.y += gravity * safeDt;
    isOnGround = false;
    position += velocity * safeDt;

    // Ground tiles
    for (final ground in game.groundComponents) {
      _resolveVertical(ground, Vector2.zero());
    }

    // Gate tertutup, moving platform (brick bisa numpang & ke-carry oleh
    // platform), dan stone brick LAIN (biar bisa numpuk, gak saling
    // tembus secara vertikal).
    for (final child in parent!.children) {
      if (child is GateComponent && !child.isOpenState) {
        _resolveVertical(child, Vector2.zero());
      } else if (child is MovingPlatformComponent) {
        final landed = _resolveVertical(child, child.frameDelta);
        if (landed) position.x += child.frameDelta.x;
      } else if (child is StoneBrickComponent && child != this) {
        _resolveVertical(child, child.frameDelta);
      }
    }

    frameDelta
      ..setFrom(position)
      ..sub(_prevFramePosition);
  }

  /// Resolve vertikal: landing (ketiban solid di bawah saat jatuh) &
  /// block dari bawah (nyodok solid dari bawah). Brick tidak pernah
  /// gerak horizontal sendiri (cuma lewat [tryPush]), jadi resolve
  /// horizontal terhadap solid lain cukup ditangani di [tryPush].
  ///
  /// SELAIN 2 kasus "arah jelas" itu, ada fallback buat overlap yang
  /// AMBIGU (brick sudah overlap dengan [other] sejak SEBELUM frame ini
  /// juga, bukan baru nyentuh) -- mis. brick di-spawn dengan sedikit
  /// nyangkut ke tanah (peletakan objek di Tiled biasanya nggak presisi
  /// 100%), atau overlap terhadap moving platform yang konfigurasi
  /// approach-nya bukan "jatuh bersih dari atas" (mis. platform yang
  /// baru mulai gerak pas brick udah standby di jalurnya). TANPA
  /// fallback ini, brick bisa "mendelep" permanen ke tanah pas spawn,
  /// atau gagal numpang sama sekali di atas moving platform -- karena
  /// dua kondisi "arah jelas" di atas sama-sama tidak terpenuhi dan
  /// tidak ada resolusi apa pun yang dijalankan.
  bool _resolveVertical(PositionComponent other, Vector2 otherDelta) {
    final tl =
        other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
    final ox = tl.x;
    final oy = tl.y;
    final ow = other.size.x;
    final oh = other.size.y;

    final overlapR = (position.x + size.x) - ox;
    final overlapL = (ox + ow) - position.x;
    final overlapB = (position.y + size.y) - oy;
    final overlapT = (oy + oh) - position.y;

    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) {
      return false;
    }

    final prevOy = oy - otherDelta.y;
    final prevBottom = _prevFramePosition.y + size.y;
    final prevTop = _prevFramePosition.y;

    if (prevBottom <= prevOy) {
      position.y = oy - size.y;
      if (velocity.y > 0) {
        velocity.y = 0;
        isOnGround = true;
        return true;
      }
      return false;
    } else if (prevTop >= prevOy + oh) {
      position.y = oy + oh;
      if (velocity.y < 0) velocity.y = 0;
      return false;
    } else {
      // Fallback ambigu: pakai sisi overlap yang LEBIH DANGKAL sebagai
      // arah resolve (konsisten dengan tie-break di
      // PlayerComponent._resolveAgainst).
      if (overlapB <= overlapT) {
        position.y = oy - size.y;
        velocity.y = 0;
        isOnGround = true;
        return true;
      } else {
        position.y = oy + oh;
        if (velocity.y < 0) velocity.y = 0;
        return false;
      }
    }
  }

  /// Coba dorong brick sejauh [dx] px (tanda menentukan arah: positif =
  /// kanan, negatif = kiri). Dipanggil PlayerComponent saat player
  /// nabrak brick ini secara horizontal. Return jarak yang BENERAN
  /// berhasil digeser — bisa lebih kecil dari [dx] kalau kehalang
  /// sesuatu di tengah jalan, atau 0 kalau kehalang total (brick tidak
  /// gerak sama sekali).
  double tryPush(double dx) {
    if (dx == 0 || parent == null) return 0;

    final desiredX = position.x + dx;
    var allowedX = desiredX;

    void clampAgainst(PositionComponent other) {
      final tl =
          other.position -
          Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
      final ox = tl.x;
      final ow = other.size.x;

      // Cuma peduli solid yang overlap secara VERTIKAL dengan brick —
      // kalau nggak sejajar tinggi, gak mungkin saling blok horizontal.
      final overlapB = (position.y + size.y) - tl.y;
      final overlapT = (tl.y + other.size.y) - position.y;
      if (overlapB <= 0 || overlapT <= 0) return;

      if (dx > 0) {
        // Dorong ke kanan: dibatasi sisi kiri 'other' kalau ada di depan.
        if (ox >= position.x + size.x - 0.01 && ox < desiredX + size.x) {
          allowedX = min(allowedX, ox - size.x);
        }
      } else {
        // Dorong ke kiri: dibatasi sisi kanan 'other'.
        final otherRight = ox + ow;
        if (otherRight <= position.x + 0.01 && otherRight > desiredX) {
          allowedX = max(allowedX, otherRight);
        }
      }
    }

    for (final ground in game.groundComponents) {
      clampAgainst(ground);
    }
    for (final child in parent!.children) {
      if (child == this) continue;
      if (child is GateComponent && !child.isOpenState) {
        clampAgainst(child);
      } else if (child is StoneBrickComponent) {
        clampAgainst(child);
      } else if (child is MovingPlatformComponent) {
        clampAgainst(child);
      }
    }

    final actualDx = allowedX - position.x;
    position.x = allowedX;
    return actualDx;
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF8A7360),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = const Color(0xFF5C4A3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Garis "bata" tipis, biar keliatan beda dari ground/platform
    // meski belum ada asset.
    final p = Paint()
      ..color = const Color(0xFF5C4A3A).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.y / 2), Offset(size.x, size.y / 2), p);
    canvas.drawLine(Offset(size.x / 2, 0), Offset(size.x / 2, size.y / 2), p);
    canvas.drawLine(
      Offset(size.x / 4, size.y / 2),
      Offset(size.x / 4, size.y),
      p,
    );
    canvas.drawLine(
      Offset(size.x * 3 / 4, size.y / 2),
      Offset(size.x * 3 / 4, size.y),
      p,
    );
  }
}
