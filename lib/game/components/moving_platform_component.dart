import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/cache.dart';

import '../tile_grid.dart';
import 'stone_brick_component.dart';

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
    this.initialMoving = true,
    // Default sama seperti behavior lama (tileset industrilla, ID 4/5/6).
    // Untuk asset custom, isi property Tiled: tilesetImage & tileGrid
    // (lihat lib/game/tile_grid.dart untuk format).
    this.tilesetImage = 'tilemap_packed_industrilla expansion.png',
    this.tileGrid = '4,5,6',
  }) : isMoving = initialMoving,
       super(anchor: Anchor.topLeft);

  final PlatformDirection direction;
  final int distanceTiles;
  final double tileSize;
  final double speed;

  /// Nama file tileset (di assets/tiles/) khusus untuk instance ini.
  final String tilesetImage;

  /// Susunan tile, lihat lib/game/tile_grid.dart untuk format.
  final String tileGrid;

  /// Snapshot state awal, dipakai grup trigger untuk hitung XOR.
  final bool initialMoving;

  /// State gerak saat ini. false = freeze di posisi terakhir.
  bool isMoving;

  void start() => isMoving = true;
  void stop() => isMoving = false;

  /// Toggle state, konsisten dengan GateComponent.toggleState().
  void toggleState() => isMoving = !isMoving;

  late final Vector2 _start;
  late final Vector2 _end;
  bool _forward = true;

  /// Pergerakan platform di frame ini, dipakai PlayerComponent untuk carry.
  final Vector2 frameDelta = Vector2.zero();

  Image? _image;
  late final TileGrid _parsedGrid;

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

    // Images() cache by filename, jadi aman dipanggil dari banyak instance.
    final images = Images(prefix: 'assets/tiles/');
    _image = await images.load(tilesetImage);
    _parsedGrid = TileGrid.parse(tileGrid);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isMoving) {
      frameDelta.setZero();
      return;
    }

    final target = _forward ? _end : _start;
    final diff = target - position;
    final dist = diff.length;

    final prev = position.clone();

    if (dist < 1) {
      _forward = !_forward;
      frameDelta.setZero();
      return;
    }

    final step = (speed * dt).clamp(0.0, dist);
    final proposed = position + diff.normalized() * step;

    if (_blockedByStoneBrick(proposed)) {
      // Ada brick menghalangi jalur, langsung balik arah lebih awal
      // daripada memaksa nembus/dorong (rawan glitch/teleport).
      _forward = !_forward;
      frameDelta.setZero();
      return;
    }

    position.setFrom(proposed);
    frameDelta.setFrom(position - prev);
  }

  /// True kalau posisi target akan overlap brick yang bukan sedang
  /// ditumpangi di atas platform ini.
  bool _blockedByStoneBrick(Vector2 proposedPosition) {
    if (parent == null) return false;
    for (final child in parent!.children) {
      if (child is! StoneBrickComponent) continue;
      if (_isRestingOnTop(child)) continue;
      if (_wouldOverlap(proposedPosition, child)) return true;
    }
    return false;
  }

  /// True kalau brick sedang nemplok tepat di atas platform.
  bool _isRestingOnTop(StoneBrickComponent brick) {
    final brickBottom = brick.position.y + brick.size.y;
    final myTop = position.y;
    final withinX =
        brick.position.x + brick.size.x > position.x &&
        brick.position.x < position.x + size.x;
    return withinX && (brickBottom - myTop).abs() < 2.0;
  }

  bool _wouldOverlap(Vector2 pos, StoneBrickComponent brick) {
    final ax1 = pos.x;
    final ay1 = pos.y;
    final ax2 = pos.x + size.x;
    final ay2 = pos.y + size.y;
    final bx1 = brick.position.x;
    final by1 = brick.position.y;
    final bx2 = brick.position.x + brick.size.x;
    final by2 = brick.position.y + brick.size.y;
    return ax1 < bx2 && ax2 > bx1 && ay1 < by2 && ay2 > by1;
  }

  @override
  void render(Canvas canvas) {
    final image = _image;
    if (image == null) return;
    renderTileGrid(canvas, image, _parsedGrid, size, tileSize);
  }
}
