import 'dart:math' show min;

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
  bool isOnGround = false;
  bool _nearExitDoor = false;
  bool _isDead = false;
  LeverComponent? nearLever;
  _HorizontalInput _input = _HorizontalInput.none;

  // Tracking state gate di frame sebelumnya untuk deteksi crush
  final Map<GateComponent, bool> _gateWasOpen = {};

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

    switch (_input) {
      case _HorizontalInput.left:
        velocity.x = -moveSpeed;
        _animComponent.animation = _walkAnim;
        _animComponent.scale.x = -1;
        _animComponent.position.x = size.x;
      case _HorizontalInput.right:
        velocity.x = moveSpeed;
        _animComponent.animation = _walkAnim;
        _animComponent.scale.x = 1;
        _animComponent.position.x = 0;
      case _HorizontalInput.none:
        velocity.x = 0;
        _animComponent.animation = _idleAnim;
    }

    velocity.y += gravity * safeDt;
    isOnGround = false;
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
      _resolveAgainst(ground);
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
            position += child.frameDelta;
          }
        }
      }
    }

    // Gate: cek crush SEBELUM resolve normal
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
            _resolveAgainst(child);
          }
          // Simpan state gate frame ini untuk dibandingkan frame berikutnya
          _gateWasOpen[child] = child.isOpenState;
        }
      }
    }

    _updateLeverProximity();
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
