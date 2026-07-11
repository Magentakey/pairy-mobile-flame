import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/cache.dart';

import '../tile_grid.dart';

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
    // ── Asset per-instance ───────────────────────────────────────────
    // Semua punya default yang SAMA PERSIS dengan behavior lama (tileset
    // "tilemap_packed_industrilla expansion.png", kolom 4/5/6 di baris
    // 0 → ID 4/5/6), jadi object Tiled lama yang belum punya custom
    // property ini tetap render identik seperti sebelumnya. Untuk pakai
    // asset lain, isi custom property di object Tiled (lihat
    // Level._spawnObjects):
    //   tilesetImage (string) — nama file, relatif ke assets/tiles/
    //   tileGrid     (string) — daftar tile ID (lihat format ID di
    //     lib/game/tile_grid.dart — sama seperti field "ID" di panel
    //     Properties Tiled saat klik satu tile), contoh 1 baris x 3
    //     kolom (kiri/tengah-repeat/kanan): "4,5,6"
    this.tilesetImage = 'tilemap_packed_industrilla expansion.png',
    this.tileGrid = '4,5,6',
  }) : isMoving = initialMoving,
       super(anchor: Anchor.topLeft);

  final PlatformDirection direction;
  final int distanceTiles;
  final double tileSize;
  final double speed;

  /// Nama file gambar tileset (di dalam assets/tiles/) yang dipakai
  /// platform INI secara spesifik — bisa beda-beda antar instance,
  /// tidak lagi satu tileset untuk semua moving platform.
  final String tilesetImage;

  /// Susunan tile (lihat lib/game/tile_grid.dart untuk format). Untuk
  /// moving platform biasanya cukup 1 baris x 3 kolom (kiri/tengah/kanan),
  /// tapi bisa juga 1x1 (semua slot sama) kalau assetnya seragam.
  final String tileGrid;

  /// Snapshot state awal, dipakai grup trigger untuk hitung
  /// `initialMoving XOR AND(semua trigger)`.
  final bool initialMoving;

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

  late final Vector2 _start;
  late final Vector2 _end;
  bool _forward = true;

  /// Pergerakan platform di frame ini — dipakai PlayerComponent untuk
  /// "menumpang" (carry) saat berdiri di atasnya.
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

    // Images() pakai cache internal keyed by filename, jadi walau ada
    // banyak MovingPlatformComponent yang share tilesetImage yang sama,
    // file gambarnya cuma di-decode sekali (aman dipanggil berkali-kali
    // dari banyak instance berbeda, termasuk yang assetnya beda-beda).
    final images = Images(prefix: 'assets/tiles/');
    _image = await images.load(tilesetImage);
    _parsedGrid = TileGrid.parse(tileGrid);
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
    final image = _image;
    if (image == null) return;
    renderTileGrid(canvas, image, _parsedGrid, size, tileSize);
  }
}
