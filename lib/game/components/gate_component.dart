import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../tile_grid.dart';

class GateComponent extends PositionComponent with CollisionCallbacks {
  GateComponent({
    required super.position,
    required super.size,
    this.initialOpen = false,
    // ── Asset per-instance (opsional) ─────────────────────────────────
    // Kalau tilesetImage & tileGrid TIDAK diisi (null/kosong), gate
    // render pakai placeholder kotak-ungu-bergaris seperti sebelumnya
    // (behavior lama, tidak ada breaking change untuk gate yang sudah
    // ada). Untuk pakai asset asli, isi keduanya lewat custom property
    // di object Tiled (lihat Level._spawnObjects):
    //   tilesetImage (string) — nama file, relatif ke assets/tiles/
    //   tileGrid     (string) — minimal 3x3, isi tile ID (lihat format
    //     ID di lib/game/tile_grid.dart — sama seperti field "ID" di
    //     panel Properties Tiled saat klik satu tile), contoh:
    //     "23,24,25;33,34,35;43,44,45"
    this.tilesetImage,
    this.tileGrid,
    this.tileSize = 18,
  }) : isOpenState = initialOpen,
       super(anchor: Anchor.bottomCenter);

  /// Snapshot state awal, dipakai grup trigger untuk hitung
  /// `initialOpen XOR AND(semua trigger)`.
  final bool initialOpen;

  final String? tilesetImage;
  final String? tileGrid;
  final double tileSize;

  ui.Image? _image;
  TileGrid? _parsedGrid;

  bool get _usesRealAsset =>
      tilesetImage != null &&
      tilesetImage!.trim().isNotEmpty &&
      tileGrid != null &&
      tileGrid!.trim().isNotEmpty;

  bool isOpenState;
  // true selama SATU frame saat gate baru saja menutup
  // → PlayerComponent menggunakan ini untuk deteksi crush
  bool justClosed = false;

  void open() {
    isOpenState = true;
    justClosed = false;
  }

  void close() {
    if (isOpenState) justClosed = true; // hanya set jika sebelumnya terbuka
    isOpenState = false;
  }

  void toggle(bool isOn) => isOn ? open() : close();

  /// Flip state apa adanya, tidak peduli parameter true/false dari
  /// lever/fountain — dipakai supaya lever/fountain murni "toggle"
  /// dan tidak memaksa gate ke state tertentu.
  void toggleState() => isOpenState ? close() : open();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));

    if (_usesRealAsset) {
      final images = Images(prefix: 'assets/tiles/');
      _image = await images.load(tilesetImage!);
      _parsedGrid = TileGrid.parse(tileGrid!);
    }
  }

  @override
  void render(Canvas canvas) {
    if (isOpenState) return;

    final image = _image;
    final grid = _parsedGrid;
    if (image != null && grid != null) {
      renderTileGrid(canvas, image, grid, size, tileSize);
      return;
    }

    // Placeholder lama (dipakai kalau tidak ada tilesetImage/tileGrid).
    final rect = size.toRect();
    canvas.drawRect(rect, Paint()..color = const Color(0xFF6A3FA0));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF9B6FD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final stripeCount = (size.y / 10).floor();
    for (int i = 1; i < stripeCount; i++) {
      final y = i * 10.0;
      canvas.drawLine(
        Offset(2, y),
        Offset(size.x - 2, y),
        Paint()
          ..color = const Color(0xFF9B6FD4).withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
  }
}
