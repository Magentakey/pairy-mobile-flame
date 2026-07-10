import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/cache.dart';

enum PlatformDirection { left, right, up, down }

/// Platform solid yang bergerak bolak-balik (ping-pong) di antara titik
/// awal dan titik awal + (direction * distanceTiles * tileSize).
class MovingPlatformComponent extends PositionComponent
    with CollisionCallbacks {
  MovingPlatformComponent({
    required super.position,
    required super.size,
    required this.direction,
    required this.distanceTiles,
    this.tileSize = 18,
    this.speed = 40, // px/detik
  }) : super(anchor: Anchor.topLeft);

  final PlatformDirection direction;
  final int distanceTiles;
  final double tileSize;
  final double speed;

  // tileset manual -_-
  static const int _tileCol = 9;
  static const int _tileRow = 2;

  late final Vector2 _start;
  late final Vector2 _end;
  bool _forward = true;

  /// Pergerakan platform di frame ini — dipakai PlayerComponent untuk
  /// "menumpang" (carry) saat berdiri di atasnya.
  final Vector2 frameDelta = Vector2.zero();

  Sprite? _tileSprite;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));

    _start = position.clone();
    final offset = switch (direction) {
      PlatformDirection.right => Vector2(distanceTiles * tileSize, 0),
      PlatformDirection.left => Vector2(-distanceTiles * tileSize, 0),
      PlatformDirection.down => Vector2(0, distanceTiles * tileSize),
      PlatformDirection.up => Vector2(0, -distanceTiles * tileSize),
    };
    _end = _start + offset;

    final images = Images(prefix: 'assets/tiles/');
    final image = await images.load('tilemap_packed.png');
    _tileSprite = Sprite(
      image,
      srcPosition: Vector2(_tileCol * tileSize, _tileRow * tileSize),
      srcSize: Vector2.all(tileSize),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = _forward ? _end : _start;
    final diff = target - position;
    final dist = diff.length;

    final prev = position.clone();

    if (dist < 1) {
      _forward = !_forward;
    } else {
      final step = (speed * dt).clamp(0.0, dist);
      position += diff.normalized() * step;
    }

    frameDelta.setFrom(position - prev);
  }

  @override
  void render(Canvas canvas) {
    final sprite = _tileSprite;
    if (sprite == null) return;
    final cols = (size.x / tileSize).ceil();
    final rows = (size.y / tileSize).ceil();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        sprite.render(
          canvas,
          position: Vector2(c * tileSize, r * tileSize),
          size: Vector2.all(tileSize),
        );
      }
    }
  }
}
