import 'dart:math' show min, max;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/sprite.dart';

import '../pairy_game.dart';
import 'exit_door_component.dart';
import 'gate_component.dart';
import 'lever_component.dart';
import 'moving_platform_component.dart';

enum _HorizontalInput { none, left, right }

class PlayerComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PairyGame> {
  PlayerComponent({required super.position}) : super(size: Vector2(26, 34));

  static const double moveSpeed = 130;
  static const double gravity = 700;
  static const double jumpVelocity = -300;
  static const double maxDt = 1 / 30;

  /// Jarak (px) di bawah batas map sebelum player dianggap "jatuh"
  /// dan mati. Dikasih buffer biar ada jeda visual jatuh dulu,
  /// bukan langsung mati pas nyentuh Y = tinggi map.
  static const double fallDeathBuffer = 80;

  final Vector2 velocity = Vector2.zero();
  final Vector2 _prevPosition = Vector2.zero();
  late final SpriteAnimationComponent _animComponent;
  late final SpriteAnimation _idleAnim;
  late final SpriteAnimation _walkAnim;
  late final List<SpriteAnimation> _jumpFrames; // index 0-2 rising, 3 landing
  double _jumpAirTimer = 0;
  double _landAnimTimer = 0;
  int _groundedStreak = 0; // jumlah frame BERTURUT-TURUT isOnGround == true
  int _airborneStreak = 0; // jumlah frame BERTURUT-TURUT isOnGround == false
  static const double _jumpFrameStepTime = 0.09;
  static const double _landAnimDuration = 0.12;

  bool isOnGround = false;
  bool _nearExitDoor = false;
  bool _isDead = false;
  LeverComponent? nearLever;
  _HorizontalInput _input = _HorizontalInput.none;

  // Tracking state gate di frame sebelumnya untuk deteksi crush
  final Map<GateComponent, bool> _gateWasOpen = {};

  /// Solid (ground/platform) yang sudah "mengklaim" player sebagai
  /// landing di FRAME INI. Dipakai untuk deteksi crush real-time:
  /// kalau ada solid LAIN yang juga mengklaim landing pada frame yang
  /// sama (mis. platform vertikal yang overlap player padahal player
  /// sudah berdiri di atas platform horizontal lain), berarti player
  /// sedang dijepit dua solid sekaligus — bukan benar-benar "pindah
  /// pijakan". Tanpa ini, heuristik _resolveAgainst (yang cuma menilai
  /// arah berdasarkan posisi frame lalu VS solid yang sedang diproses)
  /// bisa salah kira ini "landing baru" dan malah nge-snap posisi
  /// player ke atas solid kedua itu (bug: "teleport" alih-alih mati
  /// kejepit).
  PositionComponent? _groundedOnThisFrame;

  /// Moving platform yang player SUDAH nempel di atasnya sejak frame
  /// SEBELUMNYA (bukan baru mendarat frame ini). Dipakai supaya carry
  /// (`position += frameDelta`) cuma diterapkan selama benar-benar
  /// "menumpang" lanjutan — BUKAN di frame pertama kali landing.
  /// Di frame pertama landing, `position.y` hasil resolve SUDAH
  /// dihitung relatif terhadap posisi platform yang SAAT INI (sudah
  /// termasuk pergerakan frame ini via `oy`), jadi menambah frameDelta
  /// lagi di frame yang sama akan menghitung pergerakan itu 2x —
  /// menyebabkan overshoot/snap yang kelihatan seperti teleport.
  MovingPlatformComponent? _lastRestingPlatform;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.active));

    final walkImage = await game.images.load('player/walk/player_walk.png');
    _walkAnim = SpriteAnimation.fromFrameData(
      walkImage,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.15,
        textureSize: Vector2(96, 128),
      ),
    );

    final jumpImage = await game.images.load('player/jump/player_jump.png');

    // Tiap frame dijadiin animasi statis 1-frame sendiri-sendiri, biar kita
    // kontrol manual frame mana yang tampil (bukan gantungin ke loop:false
    // bawaan Flame, yang ternyata suka sempat mengulang dulu sebelum
    // benar-benar freeze).
    _jumpFrames = List.generate(4, (index) {
      return SpriteAnimation.spriteList([
        Sprite(
          jumpImage,
          srcPosition: Vector2(index * 96, 0),
          srcSize: Vector2(96, 128),
        ),
      ], stepTime: 1);
    });

    // Idle sementara pakai frame pertama walk (belum ada asset idle terpisah)
    _idleAnim = SpriteAnimation.spriteList([
      _walkAnim.frames.first.sprite,
    ], stepTime: 1);

    _animComponent = SpriteAnimationComponent(
      animation: _idleAnim,
      size: size,
      anchor: Anchor.topLeft,
    );
    add(_animComponent);
  }

  /// Assign animasi cuma kalau beda dari yang sedang jalan sekarang.
  /// Flame selalu bikin ticker baru tiap kali setter `animation` dipanggil
  /// (walau objeknya sama persis) — kalau di-assign ulang tiap frame,
  /// animasi keliatan stuck karena ke-reset ke frame 0 terus-terusan.
  void _setAnim(SpriteAnimation anim) {
    if (_animComponent.animation != anim) {
      _animComponent.animation = anim;
    }
  }

  void moveLeft() => _input = _HorizontalInput.left;
  void moveRight() => _input = _HorizontalInput.right;
  void stopMoving() => _input = _HorizontalInput.none;

  void jump() {
    if (_isDead) return;
    if (_nearExitDoor) {
      game.completeLevel();
      return;
    }
    if (isOnGround) {
      velocity.y = jumpVelocity;
      isOnGround = false;
    }
  }

  @override
  void update(double dt) {
    if (_isDead) return;
    super.update(dt);
    final safeDt = dt.clamp(0.0, maxDt);

    // Platform yang player SUDAH nempel sejak frame lalu (dipakai nanti
    // buat keputusan carry di loop moving platform).
    final wasRestingOn = _lastRestingPlatform;

    switch (_input) {
      case _HorizontalInput.left:
        velocity.x = -moveSpeed;
        _animComponent.scale.x = -1;
        _animComponent.position.x = size.x;
      case _HorizontalInput.right:
        velocity.x = moveSpeed;
        _animComponent.scale.x = 1;
        _animComponent.position.x = 0;
      case _HorizontalInput.none:
        velocity.x = 0;
    }

    // Toleransi buat "false negative" isOnGround akibat presisi floating-point
    // satu frame pas player nempel datar di tanah (bukan beneran lompat/jatuh).
    // BEDA dengan pendekatan sebelumnya (threshold kecepatan) yang salah nangkep
    // momen "velocity.y lewat 0 di puncak lompatan" sebagai "sudah mendarat".
    // Sekarang: baru dianggap BENERAN grounded kalau isOnGround true selama
    // beberapa frame BERTURUT-TURUT (debounce), bukan cuma sesaat.
    if (isOnGround) {
      _groundedStreak++;
      _airborneStreak = 0;
    } else {
      _airborneStreak++;
      _groundedStreak = 0;
    }
    // Butuh beberapa frame BERTURUT-TURUT !isOnGround dulu baru dianggap
    // "beneran lompat/jatuh" — biar kedipan 1 frame pas jalan biasa di
    // tanah datar (presisi floating-point) nggak kepanggil sebagai jump.
    // Lompatan/jatuh beneran pasti bertahan banyak frame, jadi threshold
    // kecil ini aman buat filter noise tanpa bikin delay yang kerasa.
    const int airborneConfirmFrames = 3;
    final isActuallyAirborne = _airborneStreak >= airborneConfirmFrames;

    // Pilih frame SEKALI per frame secara manual berdasarkan lama waktu di
    // udara — dijamin cuma maju 0->1->2 lalu berhenti di 2 (peak), nggak
    // bisa "kebalik ke 0" atau dobel-loop kayak sebelumnya.
    if (isActuallyAirborne) {
      _jumpAirTimer += dt;
      final frameIndex = (_jumpAirTimer / _jumpFrameStepTime).floor().clamp(
        0,
        2,
      );
      _setAnim(_jumpFrames[frameIndex]);
      _landAnimTimer = _landAnimDuration; // siap tampil sekilas begitu landing
    } else if (_landAnimTimer > 0) {
      _setAnim(_jumpFrames[3]);
      _landAnimTimer -= dt;
    } else {
      _jumpAirTimer =
          0; // reset biar lompatan berikutnya mulai dari frame 0 lagi
      if (_input != _HorizontalInput.none) {
        _setAnim(_walkAnim);
      } else {
        _setAnim(_idleAnim);
      }
    }
    velocity.y += gravity * safeDt;
    isOnGround = false;
    _groundedOnThisFrame = null;
    _prevPosition.setFrom(position);
    position += velocity * safeDt;

    // Fall-death: player jatuh keluar bawah map (border sudah dihapus,
    // jadi ini pengganti border collision buat batas bawah).
    if (position.y > game.levelHeightPx + fallDeathBuffer) {
      _die('Fell off the map');
      return;
    }

    // Ground tiles
    for (final ground in game.groundComponents) {
      if (_resolveAgainst(ground)) {
        _registerLanding(ground);
        if (_isDead) return;
      }
    }

    // Gate: cek crush SEBELUM resolve normal. Diproses SEBELUM moving
    // platform (bukan sesudah, seperti sebelumnya) — supaya kalau player
    // sedang resting di atas gate tertutup, klaim landing-nya SUDAH
    // tercatat lebih dulu di frame ini sebelum moving platform lain
    // sempat overlap dan salah kira ini "landing baru" yang tidak
    // konflik dengan apa pun (root penyebab bug teleport gate-vs-platform).
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is GateComponent) {
          final wasOpen = _gateWasOpen[child] ?? true;
          if (!child.isOpenState) {
            if (wasOpen && _aabbOverlap(child)) {
              // Gate baru tutup + player di dalam → mati tertimpa
              _die('Crushed by Gate');
              _gateWasOpen[child] = false;
              return;
            }
            if (_resolveAgainst(child)) {
              _registerLanding(child);
              if (_isDead) return;
            }
          }
          // Simpan state gate frame ini untuk dibandingkan frame berikutnya
          _gateWasOpen[child] = child.isOpenState;
        }
      }
    }

    // Moving platform: solid + bawa player ikut gerak, HANYA kalau player
    // benar-benar landing di atas platform itu spesifik frame ini.
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is MovingPlatformComponent) {
          final landedOnThis = _resolveAgainst(
            child,
            otherDelta: child.frameDelta,
          );
          if (landedOnThis) {
            _registerLanding(child);
            if (_isDead) return;
            // Carry HANYA kalau ini lanjutan resting dari frame
            // sebelumnya di platform yang SAMA. Di frame pertama
            // landing, position.y hasil resolve sudah dihitung
            // relatif ke posisi platform SAAT INI (oy sudah termasuk
            // pergerakan frame ini) — nambah frameDelta lagi di frame
            // yang sama akan menghitung pergerakan itu 2x dan bikin
            // overshoot/snap yang kelihatan seperti teleport.
            if (wasRestingOn == child) {
              position += child.frameDelta;
            }
          }
        }
      }
    }

    _checkPlatformCrush();
    if (_isDead) return;

    _lastRestingPlatform = _groundedOnThisFrame is MovingPlatformComponent
        ? _groundedOnThisFrame as MovingPlatformComponent
        : null;

    _updateLeverProximity();
  }

  /// Crush threshold (px): seberapa dalam overlap AABB dianggap "kejepit
  /// beneran", bukan cuma sentuhan wajar sesaat (mis. numpuk tipis di
  /// pojok tile). Player size 26x34, tile 18px — 6px kira-kira 1/3 tile,
  /// cukup buat menyaring noise resolve normal tapi tetap sensitif buat
  /// kasus kejepit sungguhan.
  static const double _crushOverlapThreshold = 6.0;

  /// Deteksi crush oleh moving platform. BEDA dengan gate (event diskrit
  /// buka/tutup), platform crush sifatnya kontinu: kalau player masih
  /// overlap DALAM dengan sesuatu (ground/gate/platform lain) setelah
  /// semua resolve collision frame ini selesai, PADAHAL ada moving
  /// platform yang lagi napel di player frame ini — itu artinya push-out
  /// tadi "sukses" secara lokal (player berhasil didorong keluar dari
  /// platform-nya sendiri, makanya overlap vs platform ~0) tapi dorongan
  /// itu malah nge-push player ke solid lain yang nggak ikut di-resolve
  /// ulang (ground di-resolve di AWAL frame, sebelum platform gerak).
  ///
  /// Makanya cek overlap dalamnya JANGAN cuma ke platform yang nyentuh —
  /// harus ke ground/gate/platform lain juga, baru bug platform-vs-ground
  /// (overlap sama platform sukses jadi ~0, tapi overlap sama ground
  /// masih dalam & gak kedetect) bisa ketangkep.
  void _checkPlatformCrush() {
    if (parent == null) return;

    // Trigger check-nya cuma kalau ada moving platform yang lagi napel
    // player frame ini (buffer kecil biar "baru aja disentuh" ikut
    // dihitung walau resolve udah bikin overlap-nya nyaris 0).
    final touchingMovingPlatform = parent!.children.any(
      (c) =>
          c is MovingPlatformComponent &&
          c.isMoving &&
          _aabbOverlap(c, buffer: 2),
    );
    if (!touchingMovingPlatform) return;

    for (final ground in game.groundComponents) {
      if (_deepOverlap(ground)) {
        _die('Crushed by Platform');
        return;
      }
    }

    for (final child in parent!.children) {
      if (child is GateComponent && !child.isOpenState && _deepOverlap(child)) {
        _die('Crushed by Platform');
        return;
      }
      if (child is MovingPlatformComponent && _deepOverlap(child)) {
        _die('Crushed by Platform');
        return;
      }
    }
  }

  bool _deepOverlap(PositionComponent other) {
    final tl =
        other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);

    final overlapX =
        min(position.x + size.x, tl.x + other.size.x) - max(position.x, tl.x);
    final overlapY =
        min(position.y + size.y, tl.y + other.size.y) - max(position.y, tl.y);

    return overlapX > _crushOverlapThreshold &&
        overlapY > _crushOverlapThreshold;
  }

  /// Dipanggil setiap kali sebuah solid (ground/platform) berhasil
  /// me-resolve player sebagai "landing" (isOnGround = true) pada
  /// frame ini. Kalau sebelumnya SUDAH ada solid lain yang mengklaim
  /// landing pada frame yang sama — dan salah satunya moving platform —
  /// berarti player sedang dijepit dua solid yang saling bertumpuk di
  /// posisi yang sama (mis. platform vertikal menembus ke posisi player
  /// yang sudah berdiri di platform horizontal lain). Itu kondisi
  /// kejepit sungguhan, jadi player mati di sini SEBELUM posisinya
  /// sempat di-snap/teleport ke solid kedua tsb.
  void _registerLanding(PositionComponent solid) {
    final previous = _groundedOnThisFrame;
    if (previous != null && previous != solid) {
      final involvesMovingPlatform =
          solid is MovingPlatformComponent ||
          previous is MovingPlatformComponent;
      if (involvesMovingPlatform) {
        _die('Crushed by Platform');
        return;
      }
    }
    _groundedOnThisFrame = solid;
  }

  void _die(String cause) {
    _isDead = true;
    velocity.setZero();
    _animComponent.animation = _idleAnim; // freeze
    game.playerDied(cause);
  }

  bool _aabbOverlap(PositionComponent other, {double buffer = 0}) {
    final tl =
        other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
    return position.x + size.x > tl.x - buffer &&
        position.x < tl.x + other.size.x + buffer &&
        position.y + size.y > tl.y - buffer &&
        position.y < tl.y + other.size.y + buffer;
  }

  void _updateLeverProximity() {
    if (parent == null) return;
    LeverComponent? found;
    for (final child in parent!.children) {
      if (child is LeverComponent && _aabbOverlap(child, buffer: 4)) {
        found = child;
        break;
      }
    }
    if (found != null && nearLever != found) {
      nearLever = found;
      game.leverState.value = found.isOn;
      if (!game.overlays.isActive('LeverButton')) {
        game.overlays.add('LeverButton');
      }
    } else if (found == null && nearLever != null) {
      nearLever = null;
      if (game.overlays.isActive('LeverButton')) {
        game.overlays.remove('LeverButton');
      }
    }
  }

  /// Return true kalau resolve ini SPESIFIK bikin player landing di atas
  /// [other] pada frame ini (dipakai buat carry di moving platform).
  ///
  /// [otherDelta] = pergerakan [other] pada frame ini (default diam/nol).
  /// Wajib diisi untuk object yang bergerak (mis. MovingPlatformComponent)
  /// supaya perbandingan "posisi player frame lalu" tetap relatif terhadap
  /// posisi [other] di frame lalu juga — bukan posisi [other] sekarang.
  bool _resolveAgainst(PositionComponent other, {Vector2? otherDelta}) {
    final delta = otherDelta ?? Vector2.zero();

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

    // Posisi 'other' pada frame SEBELUMNYA, biar perbandingan arah datang
    // player tetap akurat walau 'other' ikut gerak.
    final prevOx = ox - delta.x;
    final prevOy = oy - delta.y;

    final prevBottom = _prevPosition.y + size.y;
    final prevTop = _prevPosition.y;
    final prevRight = _prevPosition.x + size.x;
    final prevLeft = _prevPosition.x;

    if (prevBottom <= prevOy) {
      // Player kelihatan datang dari atas (prev frame belum overlap).
      // Ini cuma valid dianggap "landing" beneran kalau player memang
      // sedang bergerak turun (velocity.y > 0). Kalau velocity.y <= 0
      // — biasanya karena player sudah resting di solid LAIN dan
      // gravitasinya sudah di-nol-kan solid itu duluan di frame ini —
      // JANGAN paksa posisi pindah ke sini. Biarkan overlap-nya tetap
      // apa adanya, supaya _checkPlatformCrush bisa mendeteksinya
      // sebagai crush, bukan malah nge-teleport diam-diam ke atas
      // solid ini (bug lama: posisi dipindah unconditional padahal
      // return value-nya false).
      if (velocity.y > 0) {
        position.y = oy - size.y;
        velocity.y = 0;
        isOnGround = true;
        return true;
      }
      return false;
    } else if (prevTop >= prevOy + oh) {
      // Simetris dengan kasus di atas: cuma valid dianggap "nabrak
      // kepala dari bawah" kalau player memang sedang bergerak naik
      // (velocity.y < 0). Sama seperti branch di atas, JANGAN pindah
      // posisi kalau tidak — biarkan overlap terdeteksi oleh
      // _checkPlatformCrush.
      if (velocity.y < 0) {
        position.y = oy + oh;
        velocity.y = 0;
      }
    } else if (prevRight <= prevOx) {
      position.x = ox - size.x;
      velocity.x = 0;
    } else if (prevLeft >= prevOx + ow) {
      position.x = ox + ow;
      velocity.x = 0;
    } else {
      final minX = min(overlapR, overlapL);
      final minY = min(overlapB, overlapT);
      if (minY <= minX) {
        if (velocity.y >= 0) {
          position.y = oy - size.y;
          velocity.y = 0;
          isOnGround = true;
          return true;
        } else {
          position.y = oy + oh;
          velocity.y = 0;
        }
      } else {
        position.x = overlapR <= overlapL ? ox - size.x : ox + ow;
        velocity.x = 0;
      }
    }
    return false;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is ExitDoorComponent) {
      _nearExitDoor = true;
      game.nearExitDoor.value = true;
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExitDoorComponent) {
      _nearExitDoor = false;
      game.nearExitDoor.value = false;
    }
  }
}
