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
    bool initialMoving = true,
  }) : isMoving = initialMoving,
       super(anchor: Anchor.topLeft);

  final PlatformDirection direction;
  final int distanceTiles;
  final double tileSize;
  final double speed;

  /// State gerak platform saat ini. true = bergerak (default), false = diam
  /// (freeze di posisi terakhir, bukan kembali ke _start).
  /// Dikontrol lewat lever/fountain seperti halnya gate.
  bool isMoving;

  void start() => isMoving = true;
  void stop() => isMoving = false;

  /// Flip state apa adanya — dipakai supaya lever/fountain murni "toggle"
  /// dan tidak memaksa platform ke state tertentu (konsisten dengan
  /// GateComponent.toggleState()).
  void toggleState() => isMoving = !isMoving;

  // Koordinat 3-slice conveyor di tileset t3 (tilemap_packed_industrilla
  // expansion.png), row 6: kolom 4 = kiri, 5 = tengah, 6 = kanan.
  static const int _tileRow = 0;
  static const int _colLeft = 4;
  static const int _colMid = 5;
  static const int _colRight = 6;

  late final Vector2 _start;
  late final Vector2 _end;
  bool _forward = true;

  /// Pergerakan platform di frame ini — dipakai PlayerComponent untuk
  /// "menumpang" (carry) saat berdiri di atasnya.
  final Vector2 frameDelta = Vector2.zero();

  Sprite? _leftSprite;
  Sprite? _midSprite;
  Sprite? _rightSprite;

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
    final image = await images.load('tilemap_packed_industrilla expansion.png');

    Sprite tileAt(int col) => Sprite(
      image,
      srcPosition: Vector2(col * tileSize, _tileRow * tileSize),
      srcSize: Vector2.all(tileSize),
    );

    _leftSprite = tileAt(_colLeft);
    _midSprite = tileAt(_colMid);
    _rightSprite = tileAt(_colRight);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isMoving) {
      // Freeze di posisi saat ini — bukan kembali ke _start.
      frameDelta.setZero();
      return;
    }

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
    final left = _leftSprite;
    final mid = _midSprite;
    final right = _rightSprite;
    if (left == null || mid == null || right == null) return;

    final cols = (size.x / tileSize).round().clamp(1, 1 << 30);

    if (cols == 1) {
      // Cuma cukup 1 tile lebar → pakai tile tengah aja biar polos.
      mid.render(canvas, position: Vector2.zero(), size: Vector2.all(tileSize));
      return;
    }

    for (int c = 0; c < cols; c++) {
      final sprite = c == 0
          ? left
          : c == cols - 1
          ? right
          : mid;
      sprite.render(
        canvas,
        position: Vector2(c * tileSize, 0),
        size: Vector2.all(tileSize),
      );
    }
  }
}
