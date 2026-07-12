import 'dart:math' show min, max;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../pairy_game.dart';
import 'crushed_text_component.dart';
import 'gate_component.dart';
import 'moving_platform_component.dart';
import 'player_component.dart';

/// Balok batu solid:
/// - Kena gravitasi seperti player, jatuh kalau tidak ada pijakan.
/// - Bisa didorong player horizontal secara halus/kontinu, lihat [tryPush].
/// - Bisa jadi pijakan (player/brick lain ikut ter-carry lewat [frameDelta]).
/// - Bisa men-trigger ButtonComponent sebagai pengganti player.
///
/// Resolve collision ditulis manual (bukan lewat Flame CollisionCallbacks),
/// konsisten dengan PlayerComponent. Anchor.topLeft, size default 1 tile
/// (18x18), bisa dikustomisasi lewat object Tiled.
class StoneBrickComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PairyGame> {
  StoneBrickComponent({required super.position, Vector2? size})
    : super(size: size ?? Vector2(18, 18), anchor: Anchor.topLeft);

  static const double gravity = 700;
  static const double maxDt = 1 / 30;

  /// Buffer jarak (px) di bawah map sebelum brick dihancurkan (dihapus).
  static const double _fallDeathBuffer = 80;

  final Vector2 velocity = Vector2.zero();
  bool isOnGround = false;

  // Tracking state gate frame sebelumnya, sama seperti pola
  // PlayerComponent._gateWasOpen, untuk deteksi crush oleh gate.
  final Map<GateComponent, bool> _gateWasOpen = {};

  /// Perpindahan brick frame ini, dipakai untuk carry (mirip
  /// MovingPlatformComponent.frameDelta).
  final Vector2 frameDelta = Vector2.zero();

  final Vector2 _prevFramePosition = Vector2.zero();

  /// Player yang sedang "menahan" brick ini nyangkut di atas kepalanya
  /// (brick berhenti jatuh, ikut gerak horizontal player, lihat
  /// [pinAbovePlayer]). null kalau brick tidak sedang nyangkut.
  PlayerComponent? _pinnedOnPlayer;
  bool get isPinnedOnPlayer => _pinnedOnPlayer != null;
  PlayerComponent? get pinnedPlayer => _pinnedOnPlayer;

  /// Player yang barusan melepas brick ini (headroom kehalang). Dipakai
  /// bareng [_pinCooldown] untuk MENCEGAH brick langsung nyangkut ulang
  /// ke player yang sama di frame berikutnya, sebagai pengganti dorongan
  /// kecepatan horizontal (yang keliatan seperti animasi "slide").
  /// Selama cooldown, brick jatuh lurus ke bawah layaknya batu biasa.
  PlayerComponent? _recentlyReleasedFrom;
  double _pinCooldown = 0;

  /// True kalau brick BOLEH nyangkut lagi ke [player] (dipanggil dari
  /// PlayerComponent sebelum memutuskan pin).
  bool canPinTo(PlayerComponent player) =>
      !(_recentlyReleasedFrom == player && _pinCooldown > 0);

  /// Sisi nudge saat brick dilepas dari pin (headroom kehalang) -- cukup
  /// perlu tanda arahnya saja, dicapture sekali di [pinAbovePlayer].
  double _pinOffsetX = 0;

  /// Posisi X player di frame sebelumnya, selama brick sedang nyangkut.
  /// Dipakai untuk hitung [playerDx] (delta gerak player frame ini), lalu
  /// delta itu diterapkan ke brick lewat [tryPush] -- PERSIS mekanisme
  /// yang sama dipakai saat brick didorong biasa di lantai, dan sama
  /// gaya carry-nya dengan MovingPlatformComponent.frameDelta (delta
  /// inkremental, bukan hitung ulang posisi absolut tiap frame). Ini yang
  /// bikin carry di atas kepala semulus platform vertikal, sekaligus
  /// membuang recoilAgainst custom (sumber bug "pop"/jitter sebelumnya).
  double _prevPinPlayerX = 0;

  /// Dipanggil PlayerComponent begitu terdeteksi brick yang sedang jatuh
  /// menimpa kepala player: brick berhenti jatuh & "nempel" tepat di atas
  /// kepala PERSIS di posisi jatuhnya, ikut mengikuti posisi player tiap
  /// frame (lihat [update]), alih-alih terus mendorong player turun
  /// menembus tanah.
  void pinAbovePlayer(PlayerComponent player) {
    _pinnedOnPlayer = player;
    _pinOffsetX = position.x - player.position.x;
    _prevPinPlayerX = player.position.x;
    velocity.setZero();
    isOnGround = true;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
    _prevFramePosition.setFrom(position);
  }

  /// Hancurkan brick + munculkan text "Crushed" fade-out. Hanya dipakai
  /// saat ketiban Gate yang menutup (bukan untuk kasus MovingPlatform,
  /// itu ditangani lewat balik arah platform sendiri).
  void _crushByGate() {
    final par = parent;
    if (par != null) {
      par.add(CrushedTextComponent(position: position + size / 2));
    }
    removeFromParent();
  }

  bool _overlaps(PositionComponent other) {
    final tl =
        other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
    return position.x + size.x > tl.x &&
        position.x < tl.x + other.size.x &&
        position.y + size.y > tl.y &&
        position.y < tl.y + other.size.y;
  }

  /// Re-cek isOnGround setelah didorong horizontal (dipanggil
  /// PlayerComponent tepat setelah [tryPush]). Perlu karena update()
  /// brick sudah jalan sebelum player mendorongnya di frame yang sama,
  /// jadi tanpa recheck ini brick telat 1 frame sadar sudah tidak ketopang.
  void recheckGroundSupport() {
    if (!isOnGround) return;
    final stillSupported = game.groundComponents.any((g) {
      final overlapR = (position.x + size.x) - g.position.x;
      final overlapL = (g.position.x + g.size.x) - position.x;
      final touchingTop = (position.y + size.y - g.position.y).abs() < 1.0;
      return overlapR > 4.0 && overlapL > 4.0 && touchingTop;
    });
    if (!stillSupported) isOnGround = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (parent == null) return;
    final safeDt = dt.clamp(0.0, maxDt);

    _prevFramePosition.setFrom(position);

    if (_pinCooldown > 0) {
      _pinCooldown -= safeDt;
      if (_pinCooldown <= 0) {
        _pinCooldown = 0;
        _recentlyReleasedFrom = null;
      }
    }

    // Nyangkut di kepala player: skip gravity & resolve normal, cukup
    // ikuti posisi player tiap frame (mengikuti gerak kiri/kanan DAN
    // naik/turunnya player, mis. saat player jatuh/berdiri di tanjakan).
    if (_pinnedOnPlayer != null) {
      final player = _pinnedOnPlayer!;
      if (player.isMounted && !player.isDead) {
        final desiredY = player.position.y - size.y;

        // Headroom check: kalau ruang di atas kepala player (setinggi
        // brick ini) kehalang solid lain (mis. platform rendah yang
        // sebenarnya masih muat dilewati player TANPA brick di
        // kepalanya), brick tidak mungkin tetap nyangkut di situ --
        // lepas & jatuh, alih-alih clipping/nge-glitch ke dalam solid.
        bool overlapsHeadroom(PositionComponent other) {
          final tl =
              other.position -
              Vector2(
                other.size.x * other.anchor.x,
                other.size.y * other.anchor.y,
              );
          final overlapX =
              min(player.position.x + player.size.x, tl.x + other.size.x) -
              max(player.position.x, tl.x);
          if (overlapX <= 0) return false;
          final overlapY =
              min(player.position.y, tl.y + other.size.y) - max(desiredY, tl.y);
          return overlapY > 0;
        }

        var headroomBlocked = game.groundComponents.any(overlapsHeadroom);
        if (!headroomBlocked) {
          for (final other in parent!.children) {
            if (other == this) continue;
            if (other is GateComponent && !other.isOpenState) {
              headroomBlocked = overlapsHeadroom(other);
            } else if (other is StoneBrickComponent) {
              headroomBlocked = overlapsHeadroom(other);
            } else if (other is MovingPlatformComponent) {
              headroomBlocked = overlapsHeadroom(other);
            }
            if (headroomBlocked) break;
          }
        }

        if (headroomBlocked) {
          // Lepas: nudge POSISI (bukan velocity!) sedikit menyamping supaya
          // brick langsung keluar dari kolom player pas frame ini juga.
          // Brick lalu jatuh LURUS ke bawah layaknya batu biasa -- tidak
          // dikasih kecepatan horizontal, karena itu yang bikin brick
          // keliatan "meluncur"/slide alih-alih diam & jatuh vertikal.
          // Re-pin ke player yang sama dicegah lewat cooldown singkat,
          // bukan lewat drift horizontal terus-menerus.
          final sign = _pinOffsetX >= 0 ? 1.0 : -1.0;
          position.x += sign * 6;
          velocity
            ..x = 0
            ..y = 0;
          _pinnedOnPlayer = null;
          _recentlyReleasedFrom = player;
          _pinCooldown = 0.25;
          player.releasePinnedBrick(this);
          // Lanjut jatuh normal di bawah pakai posisi yang baru di-nudge ini.
        } else {
          // Set Y dulu (nempel persis di atas kepala) SEBELUM tryPush,
          // supaya cek overlap vertikal di dalam tryPush pakai tinggi
          // brick yang benar.
          position.y = desiredY;

          // Carry horizontal lewat DELTA gerak player frame ini,
          // diterapkan lewat [_moveClamped] -- clamp inti yang SAMA
          // dipakai [tryPush] (swept clamp arah-sadar terhadap
          // ground/gate/brick lain/moving platform), TAPI tanpa efek
          // samping chain-push tryPush. Brick lain yang menumpu di ATAS
          // brick pinned ini sudah dibawa lewat mekanisme
          // frameDelta/landed-carry terpisah di update()-nya sendiri --
          // kalau di sini pakai tryPush (dengan chain-push), brick yang
          // menumpu itu bakal kena dorong DUA KALI tiap frame (dobel
          // hitung delta) dan lama-lama melenceng ke satu sisi (ini
          // penyebab jitter & "cuma bisa 1 brick" sebelumnya).
          final playerDx = player.position.x - _prevPinPlayerX;
          _prevPinPlayerX = player.position.x;
          if (playerDx != 0) _moveClamped(playerDx);

          velocity.setZero();
          isOnGround = true;
          frameDelta
            ..setFrom(position)
            ..sub(_prevFramePosition);
          return;
        }
      } else {
        // Player sudah tidak ada (mati/dilepas) -- lepas pin, lanjut jatuh normal.
        _pinnedOnPlayer = null;
      }
    }

    velocity.y += gravity * safeDt;
    isOnGround = false;
    position += velocity * safeDt;

    // Jatuh keluar map -> hancur beneran, dihapus dari game.
    if (position.y > game.levelHeightPx + _fallDeathBuffer) {
      removeFromParent();
      return;
    }

    // Ground tiles
    for (final ground in game.groundComponents) {
      _resolveVertical(ground, Vector2.zero(), minSupportOverlap: 4.0);
    }

    // Gate tertutup, moving platform, dan stone brick lain (biar bisa
    // numpuk tanpa saling tembus vertikal).
    for (final child in parent!.children) {
      if (child is GateComponent) {
        final wasOpen = _gateWasOpen[child] ?? true;
        if (!child.isOpenState) {
          if (wasOpen && _overlaps(child)) {
            _crushByGate();
            return;
          }
          _resolveVertical(child, Vector2.zero(), minSupportOverlap: 4.0);
        }
        _gateWasOpen[child] = child.isOpenState;
      } else if (child is MovingPlatformComponent) {
        final landed = _resolveVertical(
          child,
          child.frameDelta,
          minSupportOverlap: 4.0,
        );
        if (landed) position.x += child.frameDelta.x;
      } else if (child is StoneBrickComponent && child != this) {
        if (_isDeeplySpawnOverlapped(child)) {
          // 2 brick ke-spawn nyaris di posisi sama di Tiled -- hapus
          // salah satu (dipilih deterministik via hashCode) supaya
          // tidak keduanya jitter berebut posisi di atas.
          if (identityHashCode(this) > identityHashCode(child)) {
            removeFromParent();
            return;
          }
        } else {
          final landed = _resolveVertical(
            child,
            child.frameDelta,
            minSupportOverlap: 4.0,
          );
          // Carry horizontal: brick yang numpu di atas brick lain harus
          // ikut kebawa kalau brick di bawahnya didorong/bergerak, sama
          // seperti carry di cabang MovingPlatformComponent di atas.
          if (landed) position.x += child.frameDelta.x;
        }
      }
    }

    frameDelta
      ..setFrom(position)
      ..sub(_prevFramePosition);
  }

  /// True kalau overlap dengan [other] jauh lebih dalam dari overlap wajar
  /// saat numpuk normal (dipakai deteksi 2 brick spawn di posisi sama).
  bool _isDeeplySpawnOverlapped(PositionComponent other) {
    final tl =
        other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
    final overlapX =
        min(position.x + size.x, tl.x + other.size.x) - max(position.x, tl.x);
    final overlapY =
        min(position.y + size.y, tl.y + other.size.y) - max(position.y, tl.y);
    return overlapX > size.x * 0.6 && overlapY > size.y * 0.6;
  }

  /// Resolve vertikal: landing & block dari bawah. Brick tidak pernah
  /// gerak horizontal sendiri (hanya lewat [tryPush]), jadi horizontal
  /// terhadap solid lain ditangani di [tryPush].
  /// Ada fallback untuk overlap ambigu (brick sudah overlap sejak
  /// sebelum frame ini, mis. spawn nyangkut dikit ke tanah atau napel
  /// moving platform yang baru mulai gerak) supaya brick tidak
  /// mendelep ke tanah atau gagal numpang.
  bool _resolveVertical(
    PositionComponent other,
    Vector2 otherDelta, {
    double minSupportOverlap = 0,
  }) {
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

    // Overlap horizontal terlalu tipis (brick lewat cepat di ujung
    // seberang jurang) -- jangan dianggap ketopang, biarkan jatuh.
    if (min(overlapR, overlapL) < minSupportOverlap) {
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
      // Fallback ambigu: pakai sisi overlap yang lebih dangkal
      // (konsisten dengan tie-break di PlayerComponent._resolveAgainst).
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

  /// Coba dorong brick sejauh [dx] px (positif = kanan, negatif = kiri).
  /// Return jarak yang beneran berhasil digeser (bisa < dx atau 0 kalau
  /// kehalang). Chain-push ke sibling/brick yang menumpu di atas dipakai
  /// untuk skenario "player mendorong brick di lantai".
  double tryPush(double dx) {
    if (dx == 0 || parent == null) return 0;

    // Clamp gerak brick INI SENDIRI DULU, sebelum chain-push ke
    // sibling/brick yang menumpu di atas. Urutan ini penting: kalau
    // chain-push dilakukan duluan pakai [dx] mentah (urutan lama), brick
    // yang menumpu di atas / brick lain dalam antrian bisa "kebablasan"
    // maju penuh padahal brick yang ditumpu/di depannya ternyata mentok
    // duluan (mis. brick paling bawah kena tembok, tapi brick di atasnya
    // tetap maju menembus batas). Dengan clamp dulu, kita tahu persis
    // [actualDx] (jarak yang BENERAN tercapai) sebelum meneruskannya ke
    // sibling, sehingga seluruh tumpukan/antrian berhenti bersamaan.
    final actualDx = _moveClamped(dx);

    if (actualDx != 0) {
      // Chain push horizontal: kalau ada brick lain nempel di sisi arah
      // dorongan, ikut dorong dia (rekursif) sejauh actualDx (bukan dx
      // mentah).
      for (final sibling in parent!.children) {
        if (sibling == this || sibling is! StoneBrickComponent) continue;
        final sTl =
            sibling.position -
            Vector2(
              sibling.size.x * sibling.anchor.x,
              sibling.size.y * sibling.anchor.y,
            );
        final overlapB = (position.y + size.y) - sTl.y;
        final overlapT = (sTl.y + sibling.size.y) - position.y;
        if (overlapB <= 0 || overlapT <= 0) continue;

        const gapTol = 0.5;
        if (dx > 0) {
          if ((sTl.x - (position.x + size.x)).abs() <= gapTol) {
            sibling.tryPush(actualDx);
            sibling.recheckGroundSupport();
          }
        } else {
          if ((position.x - (sTl.x + sibling.size.x)).abs() <= gapTol) {
            sibling.tryPush(actualDx);
            sibling.recheckGroundSupport();
          }
        }
      }

      // Chain push VERTIKAL: brick lain yang lagi numpu PERSIS di atas
      // brick ini (menumpuk) ikut digeser actualDx yang sama, supaya
      // tumpukan bergerak bareng DAN berhenti bareng (rekursif, kalau
      // ada brick ke-3 numpu di brick ke-2, ikut kebawa lewat panggilan
      // tryPush sibling di bawah).
      for (final onTop in parent!.children) {
        if (onTop == this || onTop is! StoneBrickComponent) continue;
        final tTl =
            onTop.position -
            Vector2(
              onTop.size.x * onTop.anchor.x,
              onTop.size.y * onTop.anchor.y,
            );
        final overlapR = (position.x + size.x) - tTl.x;
        final overlapL = (tTl.x + onTop.size.x) - position.x;
        if (overlapR <= 0 || overlapL <= 0) continue; // gak overlap horizontal

        const gapTol = 0.5;
        final onTopBottom = tTl.y + onTop.size.y;
        if ((onTopBottom - position.y).abs() <= gapTol) {
          // onTop persis numpu di atas brick ini -> ikut geser.
          onTop.tryPush(actualDx);
        }
      }
    }

    return actualDx;
  }

  /// Gerakkan brick ini sendiri sejauh [dx] px, diclamp terhadap
  /// ground/gate/brick lain/moving platform -- TANPA efek samping
  /// chain-push ke sibling lain. Dipakai oleh [tryPush] (untuk hitung
  /// actualDx sebelum chain-push), dan juga dipakai LANGSUNG untuk carry
  /// inkremental brick yang lagi nyangkut di kepala player (lihat
  /// [pinAbovePlayer] & [update]) -- supaya TIDAK dobel-hitung delta
  /// dengan mekanisme frameDelta/landed-carry biasa yang sudah dipakai
  /// brick lain yang menumpu di atasnya.
  double _moveClamped(double dx) {
    final desiredX = position.x + dx;
    var allowedX = desiredX;

    void clampAgainst(PositionComponent other) {
      final tl =
          other.position -
          Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
      final ox = tl.x;
      final ow = other.size.x;

      // Cuma peduli solid yang overlap vertikal dengan brick.
      final overlapB = (position.y + size.y) - tl.y;
      final overlapT = (tl.y + other.size.y) - position.y;
      if (overlapB <= 0 || overlapT <= 0) return;

      if (dx > 0) {
        if (ox >= position.x + size.x - 0.01 && ox < desiredX + size.x) {
          allowedX = min(allowedX, ox - size.x);
        }
      } else {
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
    // Garis "bata" tipis biar beda dari ground/platform.
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
