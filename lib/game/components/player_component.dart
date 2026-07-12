import 'dart:math' show min, max;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/sprite.dart';

import '../pairy_game.dart';
import '../../services/audio_service.dart';
import 'exit_door_component.dart';
import 'gate_component.dart';
import 'lever_component.dart';
import 'moving_platform_component.dart';
import 'stone_brick_component.dart';

enum _HorizontalInput { none, left, right }

/// Arah dorongan sebuah solid terhadap player, dipakai untuk deteksi
/// jepitan sebelum resolve dijalankan.
enum _PushDir { up, down, left, right }

class PlayerComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PairyGame> {
  PlayerComponent({required super.position})
    : super(size: PlayerComponent.hitboxSize);

  /// Ukuran hitbox player, dipakai juga oleh Level untuk hitung spawn.
  static final Vector2 hitboxSize = Vector2(26, 34);

  static const double moveSpeed = 130;
  static const double gravity = 700;
  static const double jumpVelocity = -300;
  static const double maxDt = 1 / 30;

  /// Buffer jarak (px) di bawah map sebelum player dianggap jatuh & mati.
  static const double fallDeathBuffer = 80;

  final Vector2 velocity = Vector2.zero();
  final Vector2 _prevPosition = Vector2.zero();
  late final SpriteAnimationComponent _animComponent;
  late final SpriteAnimation _idleAnim;
  late final SpriteAnimation _walkAnim;
  late final List<SpriteAnimation> _jumpFrames; // index 0-2 rising, 3 landing
  double _jumpAirTimer = 0;
  double _landAnimTimer = 0;
  int _groundedStreak = 0;
  int _airborneStreak = 0;
  static const double _jumpFrameStepTime = 0.09;
  static const double _landAnimDuration = 0.12;

  bool isOnGround = false;
  // Set (bukan boolean tunggal) supaya overlap 2+ ExitDoor tidak saling
  // mematikan status saat salah satunya collision-end duluan.
  final Set<ExitDoorComponent> _touchingExitDoors = {};
  bool get _nearExitDoor => _touchingExitDoors.isNotEmpty;
  bool _isDead = false;
  bool get isDead => _isDead;
  LeverComponent? nearLever;
  _HorizontalInput _input = _HorizontalInput.none;

  final Map<GateComponent, bool> _gateWasOpen = {};

  /// Platform yang sedang ditumpangi player (sticky antar-frame), supaya
  /// platform turun cepat tidak bikin player "lepas" & jatuh bebas.
  MovingPlatformComponent? _restingPlatform;

  /// StoneBrick yang sedang nyangkut di atas kepala player (lihat
  /// StoneBrickComponent.pinAbovePlayer). Selama tidak null, player tidak
  /// bisa lompat.
  StoneBrickComponent? _pinningBrick;
  bool get isPinnedByBrick => _pinningBrick != null;

  /// Dipanggil StoneBrickComponent sendiri saat brick yang nyangkut
  /// terlepas (mis. headroom kehalang platform rendah). Player jadi
  /// bisa lompat lagi.
  void releasePinnedBrick(StoneBrickComponent brick) {
    if (_pinningBrick == brick) _pinningBrick = null;
  }

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

    // Tiap frame jadi animasi statis 1-frame agar frame yang tampil
    // dikontrol manual.
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

    // Sprite dilebihin dikit ke bawah (visual saja, hitbox tetap) untuk
    // kompensasi rounding biar boots tidak ngambang dari tanah.
    const double visualGroundOverlap = 2;
    _animComponent = SpriteAnimationComponent(
      animation: _idleAnim,
      size: Vector2(size.x, size.y + visualGroundOverlap),
      anchor: Anchor.topLeft,
    );
    add(_animComponent);
  }

  /// Assign animasi hanya kalau beda, supaya tidak reset ke frame 0 tiap frame.
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
    if (_pinningBrick != null) return;
    if (_nearExitDoor) {
      game.completeLevel();
      return;
    }
    if (isOnGround) {
      velocity.y = jumpVelocity;
      isOnGround = false;
      _restingPlatform = null;
      AudioService.playJump();
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

    // Toleransi false-negative isOnGround akibat presisi floating-point.
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

    // Cek kejepit (squeeze) sebelum resolve collision sequential berjalan,
    // supaya deteksi tidak tergantung urutan resolve.
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

    // Gate: cek crush sebelum resolve normal.
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

    // Moving platform: solid + membawa player ikut gerak.
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is! MovingPlatformComponent) continue;

        if (!isOnGround && _restingPlatform == child) {
          // Sticky re-catch: platform turun lebih cepat dari gravitasi
          // player, jadi tetap dianggap napel selama sejajar & tidak lompat.
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
          // Cuma bawa komponen X, Y sudah dihitung di _resolveAgainst.
          position.x += child.frameDelta.x;
          _restingPlatform = child;
        }
      }
    }

    // Stone brick: solid + bisa didorong horizontal + bisa jadi pijakan.
    if (parent != null) {
      for (final child in parent!.children) {
        if (child is! StoneBrickComponent) continue;

        // Brick ini sudah nyangkut di kepala player (sendiri) -- posisinya
        // sudah dikelola penuh oleh StoneBrickComponent.update(), tidak
        // perlu diresolve lagi di sini.
        if (child.pinnedPlayer == this) continue;

        final tl = _topLeft(child);
        final ox = tl.x;
        final oy = tl.y;
        final ow = child.size.x;
        final oh = child.size.y;

        final overlapR = (position.x + size.x) - ox;
        final overlapL = (ox + ow) - position.x;
        final overlapB = (position.y + size.y) - oy;
        final overlapT = (oy + oh) - position.y;
        if (overlapR <= 0 || overlapL <= 0 || overlapB <= 0 || overlapT <= 0) {
          continue;
        }

        final delta = child.frameDelta;
        final prevOx = ox - delta.x;
        final prevOy = oy - delta.y;
        final prevBottom = _prevPosition.y + size.y;
        final prevTop = _prevPosition.y;
        final prevRight = _prevPosition.x + size.x;
        final prevLeft = _prevPosition.x;

        if (prevBottom <= prevOy) {
          // Landing di atas brick, brick jadi pijakan (carry X saja).
          position.y = oy - size.y;
          if (velocity.y > 0) {
            velocity.y = 0;
            isOnGround = true;
            position.x += delta.x;
            _restingPlatform = null;
          }
        } else if (prevTop >= prevOy + oh) {
          if (!child.isOnGround && child.velocity.y > 0) {
            // Brick sedang jatuh bebas dan menimpa kepala player --
            // biarkan nyangkut di atas kepala & ikut player, JANGAN
            // dorong player turun (dulu ini bikin player mendelep ke
            // tanah karena brick terus "mendorong" turun selagi jatuh).
            child.pinAbovePlayer(this);
            _pinningBrick = child;
          } else {
            // Brick statis/sudah bertumpu (mis. player lompat kejedot
            // brick dari bawah) -- perilaku normal: stop lompatan.
            position.y = oy + oh;
            if (velocity.y < 0) velocity.y = 0;
          }
        } else if (prevRight <= prevOx) {
          // Nabrak dari kiri -> dorong ke kanan.
          final moved = child.tryPush(overlapR);
          child.recheckGroundSupport();
          position.x = (ox + moved) - size.x;
          velocity.x = 0;
        } else if (prevLeft >= prevOx + ow) {
          // Nabrak dari kanan -> dorong ke kiri.
          final moved = child.tryPush(-overlapL);
          child.recheckGroundSupport();
          position.x = (ox + moved) + ow;
          velocity.x = 0;
        } else {
          // Fallback horizontal saja (vertikal sudah diresolve ground di atas).
          if (overlapR <= overlapL) {
            final moved = child.tryPush(overlapR);
            child.recheckGroundSupport();
            position.x = (ox + moved) - size.x;
          } else {
            final moved = child.tryPush(-overlapL);
            child.recheckGroundSupport();
            position.x = (ox + moved) + ow;
          }
          velocity.x = 0;
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

  /// Klasifikasi arah dorongan [other] terhadap player, tanpa mengubah
  /// posisi (dipakai oleh _detectSqueezeCrush).
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

  /// True kalau player terjepit di antara 2 solid dengan arah dorongan
  /// berlawanan pada sumbu yang sama, minimal salah satunya moving platform.
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
        // StoneBrickComponent sengaja tidak diikutkan di sini karena
        // posisinya aktif berubah (bisa false-positive), sudah dicover
        // lewat _checkPlatformCrush (deep overlap pasca-resolve).
      }
    }

    return conflict && involvesMover;
  }

  static const double _crushOverlapThreshold = 6.0;

  void _checkPlatformCrush() {
    if (parent == null) return;

    // StoneBrickComponent sengaja tidak diikutkan (deep-overlap check
    // untuk brick rawan false-positive saat didorong), jadi mekanisme
    // "kejepit brick" dimatikan total.
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

    // Kumpulkan semua lever yang overlap saat ini (bisa lebih dari satu).
    final overlapping = <LeverComponent>[];
    for (final child in parent!.children) {
      if (child is LeverComponent && _aabbOverlap(child, buffer: 4)) {
        overlapping.add(child);
      }
    }

    if (overlapping.isEmpty) {
      if (nearLever != null) {
        nearLever = null;
        if (game.overlays.isActive('LeverButton')) {
          game.overlays.remove('LeverButton');
        }
      }
      return;
    }

    // Pertahankan lever yang sedang dipilih kalau masih overlap, supaya
    // tidak flip-flop saat 2+ lever overlap bersamaan.
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

  /// True kalau resolve ini bikin player landing di atas [other] frame ini
  /// (dipakai untuk carry di moving platform).
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
      // >= 0 supaya player yang lagi diam di atas solid lain tetap bisa
      // pindah pijakan ke solid baru (mis. platform vertikal) tanpa
      // "teleport balik" ke solid lama.
      if (velocity.y >= 0) {
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
      game.nearExitDoor.value = _touchingExitDoors.isNotEmpty;
    }
  }
}
