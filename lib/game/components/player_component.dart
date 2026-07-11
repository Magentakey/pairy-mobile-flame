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

/// Arah dorongan yang dituntut sebuah solid terhadap player, dipakai buat
/// deteksi jepitan SEBELUM resolve mana pun dijalankan (lihat _classifyPush).
enum _PushDir { up, down, left, right }

class PlayerComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PairyGame> {
  PlayerComponent({required super.position})
    : super(size: PlayerComponent.hitboxSize);

  /// Ukuran hitbox player — dijadikan satu sumber kebenaran (dipakai juga
  /// oleh Level saat menghitung posisi spawn dari object Tiled), supaya
  /// tidak ada lagi angka ajaib yang bisa nyimpang dari ukuran ini kalau
  /// suatu saat berubah lagi.
  static final Vector2 hitboxSize = Vector2(26, 34);

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
  // Pakai Set (bukan boolean tunggal) supaya kalau ada 2+ ExitDoor yang
  // overlap sekaligus, keluar dari overlap salah satu pintu (collision end)
  // TIDAK langsung mematikan status "near exit door" selama masih ada
  // pintu lain yang masih overlap.
  final Set<ExitDoorComponent> _touchingExitDoors = {};
  bool get _nearExitDoor => _touchingExitDoors.isNotEmpty;
  bool _isDead = false;
  LeverComponent? nearLever;
  _HorizontalInput _input = _HorizontalInput.none;

  // Tracking state gate di frame sebelumnya untuk deteksi crush
  final Map<GateComponent, bool> _gateWasOpen = {};

  /// Moving platform yang player SEDANG ditumpangi (sticky antar-frame).
  /// Dipakai supaya kalau platform ini turun LEBIH CEPAT daripada
  /// percepatan gravitasi player (yang tiap abis nempel mulai dari
  /// velocity.y=0), dan kontak AABB sempat renggang sesaat karenanya,
  /// player TETAP dianggap napel (bukan malah jatuh bebas & isOnGround
  /// jadi false beberapa frame, yang bikin lompat gagal terus).
  MovingPlatformComponent? _restingPlatform;

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

    // Render sprite dilebihin sedikit ke bawah (cuma visual, TIDAK
    // mengubah `size`/hitbox asli yang dipakai physics & collision).
    // Ini buat kompensasi sub-pixel rounding antara sprite scaling vs
    // posisi hitbox, yang kalau dibiarkan bikin boots keliatan ngambang
    // ~1px dari permukaan tanah.
    const double visualGroundOverlap = 2;
    _animComponent = SpriteAnimationComponent(
      animation: _idleAnim,
      size: Vector2(size.x, size.y + visualGroundOverlap),
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
      _restingPlatform = null;
    }
  }

  @override
  void update(double dt) {
    if (_isDead) return;
    super.update(dt);
    final safeDt = dt.clamp(0.0, maxDt);

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
    if (isOnGround) {
      _groundedStreak++;
      _airborneStreak = 0;
    } else {
      _airborneStreak++;
      _groundedStreak = 0;
    }
    const int airborneConfirmFrames = 3;
    final isActuallyAirborne = _airborneStreak >= airborneConfirmFrames;

    if (isActuallyAirborne) {
      _jumpAirTimer += dt;
      final frameIndex = (_jumpAirTimer / _jumpFrameStepTime).floor().clamp(
        0,
        2,
      );
      _setAnim(_jumpFrames[frameIndex]);
      _landAnimTimer = _landAnimDuration;
    } else if (_landAnimTimer > 0) {
      _setAnim(_jumpFrames[3]);
      _landAnimTimer -= dt;
    } else {
      _jumpAirTimer = 0;
      if (_input != _HorizontalInput.none) {
        _setAnim(_walkAnim);
      } else {
        _setAnim(_idleAnim);
      }
    }

    velocity.y += gravity * safeDt;
    isOnGround = false;
    _prevPosition.setFrom(position);
    position += velocity * safeDt;

    // Fall-death: player jatuh keluar bawah map.
    if (position.y > game.levelHeightPx + fallDeathBuffer) {
      _die('Fell off the map');
      return;
    }

    // ── PRE-RESOLVE CRUSH CHECK ─────────────────────────────────────────
    // Klasifikasikan arah dorongan tiap solid yang overlap player SAAT INI,
    // SEBELUM resolve mana pun dijalankan. Kalau ada 2 solid yang menuntut
    // arah berlawanan pada sumbu yang sama (satu minta player didorong ke
    // ATAS, yang lain ke BAWAH -- atau satu ke KIRI, lainnya ke KANAN) --
    // itu tandanya player benar-benar terjepit di antara dua solid yang
    // saling mendekat dari 2 sisi. Ini dicek SEBELUM & TERPISAH dari resolve
    // sequential (Ground -> Gate -> Platform) supaya TIDAK tergantung urutan
    // resolve -- resolve sequential yang lama bisa "berhasil" menghindar
    // dari overlap salah satu sisi sebagai efek samping, yang bikin overlap
    // sisi lainnya ikut hilang juga, alih-alih benar-benar mendeteksi
    // jepitannya (itulah kenapa sebelumnya kejadiannya "teleport" bukan
    // mati).
    if (_detectSqueezeCrush()) {
      _die('Crushed by Platform');
      return;
    }

    // Ground tiles
    for (final ground in game.groundComponents) {
      _resolveAgainst(ground);
    }
    if (isOnGround) {
      _restingPlatform = null;
    }

    // Gate: cek crush SEBELUM resolve normal.
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is GateComponent) {
          final wasOpen = _gateWasOpen[child] ?? true;
          if (!child.isOpenState) {
            if (wasOpen && _aabbOverlap(child)) {
              _die('Crushed by Gate');
              _gateWasOpen[child] = false;
              return;
            }
            _resolveAgainst(child);
            if (isOnGround) _restingPlatform = null;
          }
          _gateWasOpen[child] = child.isOpenState;
        }
      }
    }

    // Moving platform: solid + bawa player ikut gerak.
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is! MovingPlatformComponent) continue;

        if (!isOnGround && _restingPlatform == child) {
          // Sticky re-catch: platform ini turun lebih cepat dari
          // percepatan gravitasi player, jadi kontak AABB sempat
          // renggang sesaat. Selama player masih sejajar horizontal
          // dengan platform & tidak sedang lompat (velocity.y >= 0),
          // tetap anggap napel -- jangan biarkan jatuh bebas cuma
          // karena telat 1-2 frame nyusul turunnya platform.
          final tl = _topLeft(child);
          final stillAligned =
              position.x + size.x > tl.x && position.x < tl.x + child.size.x;
          if (stillAligned && velocity.y >= 0) {
            position.y = tl.y - size.y;
            position.x += child.frameDelta.x;
            velocity.y = 0;
            isOnGround = true;
            continue;
          } else {
            _restingPlatform = null;
          }
        }

        final landedOnThis = _resolveAgainst(
          child,
          otherDelta: child.frameDelta,
        );
        if (landedOnThis) {
          // PENTING: cuma bawa komponen X dari frameDelta. Komponen Y
          // TIDAK boleh ditambahkan lagi -- _resolveAgainst di atas
          // sudah menghitung position.y memakai posisi platform yang
          // SUDAH ter-update frame ini. Menambah frameDelta.y lagi
          // di sini men-double-count pergerakan vertikal SETIAP FRAME
          // selama player naik di platform vertikal.
          position.x += child.frameDelta.x;
          _restingPlatform = child;
        }
      }
    }

    _checkPlatformCrush();
    if (_isDead) return;

    _updateLeverProximity();
  }

  Vector2 _topLeft(PositionComponent other) {
    return other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
  }

  /// Tentukan arah dorongan yang dituntut [other] terhadap player SAAT INI,
  /// TANPA mengubah posisi apa pun (murni klasifikasi, dipakai buat
  /// _detectSqueezeCrush). Logikanya sengaja dibuat konsisten dengan
  /// _resolveAgainst supaya hasil klasifikasi selaras dengan resolve yang
  /// beneran dijalankan nanti.
  _PushDir? _classifyPush(PositionComponent other, Vector2 delta) {
    final tl = _topLeft(other);
    final ox = tl.x;
    final oy = tl.y;
    final ow = other.size.x;
    final oh = other.size.y;

    final overlapR = (position.x + size.x) - ox;
    final overlapL = (ox + ow) - position.x;
    final overlapB = (position.y + size.y) - oy;
    final overlapT = (oy + oh) - position.y;

    if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) {
      return null;
    }

    final prevOx = ox - delta.x;
    final prevOy = oy - delta.y;

    final prevBottom = _prevPosition.y + size.y;
    final prevTop = _prevPosition.y;
    final prevRight = _prevPosition.x + size.x;
    final prevLeft = _prevPosition.x;

    if (prevBottom <= prevOy) return _PushDir.up;
    if (prevTop >= prevOy + oh) return _PushDir.down;
    if (prevRight <= prevOx) return _PushDir.left;
    if (prevLeft >= prevOx + ow) return _PushDir.right;

    final minX = min(overlapR, overlapL);
    final minY = min(overlapB, overlapT);
    if (minY <= minX) {
      return velocity.y >= 0 ? _PushDir.up : _PushDir.down;
    }
    return overlapR <= overlapL ? _PushDir.left : _PushDir.right;
  }

  /// True kalau player terjepit di antara 2 solid yang menuntut arah
  /// dorongan berlawanan pada sumbu yang sama (atas+bawah, atau kiri+kanan)
  /// SECARA BERSAMAAN, dan minimal salah satunya adalah moving platform
  /// (solid statis vs statis harusnya nggak pernah saling berlawanan kalau
  /// level didesain benar, jadi ini jaga-jaga aja).
  bool _detectSqueezeCrush() {
    _PushDir? verticalPush;
    _PushDir? horizontalPush;
    var conflict = false;
    var involvesMover = false;

    void consider(PositionComponent solid, Vector2 delta, bool isMover) {
      if (conflict) return;
      final dir = _classifyPush(solid, delta);
      if (dir == null) return;
      if (isMover) involvesMover = true;
      if (dir == _PushDir.up || dir == _PushDir.down) {
        if (verticalPush != null && verticalPush != dir) {
          conflict = true;
          return;
        }
        verticalPush = dir;
      } else {
        if (horizontalPush != null && horizontalPush != dir) {
          conflict = true;
          return;
        }
        horizontalPush = dir;
      }
    }

    for (final ground in game.groundComponents) {
      consider(ground, Vector2.zero(), false);
    }
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is GateComponent && !child.isOpenState) {
          consider(child, Vector2.zero(), false);
        } else if (child is MovingPlatformComponent) {
          consider(child, child.frameDelta, true);
        }
      }
    }

    return conflict && involvesMover;
  }

  static const double _crushOverlapThreshold = 6.0;

  void _checkPlatformCrush() {
    if (parent == null) return;

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
    final tl = _topLeft(other);

    final overlapX =
        min(position.x + size.x, tl.x + other.size.x) - max(position.x, tl.x);
    final overlapY =
        min(position.y + size.y, tl.y + other.size.y) - max(position.y, tl.y);

    return overlapX > _crushOverlapThreshold &&
        overlapY > _crushOverlapThreshold;
  }

  void _die(String cause) {
    _isDead = true;
    velocity.setZero();
    _animComponent.animation = _idleAnim;
    game.playerDied(cause);
  }

  bool _aabbOverlap(PositionComponent other, {double buffer = 0}) {
    final tl = _topLeft(other);
    return position.x + size.x > tl.x - buffer &&
        position.x < tl.x + other.size.x + buffer &&
        position.y + size.y > tl.y - buffer &&
        position.y < tl.y + other.size.y + buffer;
  }

  void _updateLeverProximity() {
    if (parent == null) return;

    // Kumpulkan SEMUA lever yang overlap saat ini (bisa lebih dari satu
    // kalau ada 2+ lever berdekatan), bukan cuma ambil match pertama.
    final overlapping = <LeverComponent>[];
    for (final child in parent!.children) {
      if (child is LeverComponent && _aabbOverlap(child, buffer: 4)) {
        overlapping.add(child);
      }
    }

    if (overlapping.isEmpty) {
      // Benar-benar tidak ada lever manapun yang overlap → matikan HUD.
      if (nearLever != null) {
        nearLever = null;
        if (game.overlays.isActive('LeverButton')) {
          game.overlays.remove('LeverButton');
        }
      }
      return;
    }

    // Kalau lever yang lagi dipilih masih ada di antara yang overlap,
    // pertahankan dia (supaya tidak flip-flop antar lever saat 2+ lever
    // sama-sama overlap). Kalau tidak, baru pilih salah satu dari yang
    // masih overlap.
    final stillValid = nearLever != null && overlapping.contains(nearLever);
    final chosen = stillValid ? nearLever! : overlapping.first;

    if (nearLever != chosen) {
      nearLever = chosen;
    }
    game.leverState.value = chosen.isOn;
    if (!game.overlays.isActive('LeverButton')) {
      game.overlays.add('LeverButton');
    }
  }

  /// Return true kalau resolve ini SPESIFIK bikin player landing di atas
  /// [other] pada frame ini (dipakai buat carry di moving platform).
  bool _resolveAgainst(PositionComponent other, {Vector2? otherDelta}) {
    final delta = otherDelta ?? Vector2.zero();

    final tl = _topLeft(other);
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

    final prevOx = ox - delta.x;
    final prevOy = oy - delta.y;

    final prevBottom = _prevPosition.y + size.y;
    final prevTop = _prevPosition.y;
    final prevRight = _prevPosition.x + size.x;
    final prevLeft = _prevPosition.x;

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
      _touchingExitDoors.add(other);
      game.nearExitDoor.value = true;
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExitDoorComponent) {
      _touchingExitDoors.remove(other);
      // Cuma matikan status kalau BENAR-BENAR sudah tidak overlap
      // pintu manapun (bukan cuma satu dari beberapa pintu yang overlap).
      game.nearExitDoor.value = _touchingExitDoors.isNotEmpty;
    }
  }
}
