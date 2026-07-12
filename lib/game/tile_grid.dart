import 'dart:ui';

import 'package:flame/components.dart';

/// Template NxM (baris x kolom) tile-ID yang di-"stretch" ke ukuran
/// komponen sesungguhnya, gaya 9-slice: edge (baris/kolom pertama &
/// terakhir) tetap, interior di-tile berulang (bukan stretch/blur) biar
/// pixel art tetap tajam. Interior lebih dari 1 -> cycle untuk variasi.
///
/// Minimal grid 1x1 (semua slot sama). Umumnya: 1x3 untuk kiri/tengah/
/// kanan (conveyor), 3x3 untuk 9-slice penuh (gate).
///
/// ## Format string: tile ID, bukan col/row manual
/// Baris dipisah `;`, ID dalam baris dipisah `,`. Angka = tile ID lokal
/// tileset (sama seperti field "ID" di panel Properties Tiled).
/// Contoh: "4,5,6" (1x3) atau "23,24,25;33,34,35;43,44,45" (3x3).
class TileGrid {
  TileGrid._(this._rows);

  final List<List<int>> _rows;

  int get rowCount => _rows.length;
  int get colCount => _rows.isEmpty ? 0 : _rows.first.length;

  /// Tile ID (lokal terhadap tileset-nya) pada posisi grid ini.
  int idAt(int row, int col) => _rows[row][col];

  static TileGrid parse(String spec) {
    final rows = spec
        .split(';')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          return line
              .split(',')
              .map((cell) => cell.trim())
              .where((cell) => cell.isNotEmpty)
              .map((cell) {
                final id = int.tryParse(cell);
                if (id == null) {
                  throw FormatException(
                    'Tile ID tidak valid: "$cell" (harus angka bulat), '
                    'spec asli: "$spec"',
                  );
                }
                return id;
              })
              .toList();
        })
        .toList();

    if (rows.isEmpty || rows.any((r) => r.isEmpty)) {
      throw FormatException('Tile grid kosong atau ada baris kosong: "$spec"');
    }
    final width = rows.first.length;
    if (rows.any((r) => r.length != width)) {
      throw FormatException(
        'Semua baris tile grid harus punya jumlah kolom yang sama: "$spec"',
      );
    }
    return TileGrid._(rows);
  }
}

/// Render [grid] pakai tileset [image] (tiap tile [tileSize]x[tileSize]px
/// di source image), diskalakan mengisi [targetSize] dengan aturan
/// 9-slice + repeat interior (lihat [TileGrid]).
///
/// Kolom tileset dihitung dari `image.width ~/ tileSize`, sama seperti
/// cara Tiled menomori ID tile, jadi ID dari panel Properties Tiled
/// selalu cocok tanpa perlu properti tambahan.
void renderTileGrid(
  Canvas canvas,
  Image image,
  TileGrid grid,
  Vector2 targetSize,
  double tileSize,
) {
  final rows = grid.rowCount;
  final cols = grid.colCount;

  final tilesetColumns = (image.width / tileSize).round().clamp(1, 1 << 30);

  final slotCountX = (targetSize.x / tileSize).round().clamp(1, 1 << 30);
  final slotCountY = (targetSize.y / tileSize).round().clamp(1, 1 << 30);

  for (int sy = 0; sy < slotCountY; sy++) {
    final srcRow = _sliceIndex(sy, slotCountY, rows);
    for (int sx = 0; sx < slotCountX; sx++) {
      final srcCol = _sliceIndex(sx, slotCountX, cols);
      final id = grid.idAt(srcRow, srcCol);
      final tileCol = id % tilesetColumns;
      final tileRow = id ~/ tilesetColumns;
      final sprite = Sprite(
        image,
        srcPosition: Vector2(tileCol * tileSize, tileRow * tileSize),
        srcSize: Vector2.all(tileSize),
      );
      sprite.render(
        canvas,
        position: Vector2(sx * tileSize, sy * tileSize),
        size: Vector2.all(tileSize),
      );
    }
  }
}

/// Map index slot render ke index baris/kolom di grid definisi:
/// - defCount == 1: semua slot pakai definisi itu-itu saja.
/// - slotCount == 1: pakai definisi tengah.
/// - slot pertama/terakhir: selalu edge pertama/terakhir.
/// - defCount == 2 tapi slotCount > 2: slot tengah fallback ke definisi terakhir.
/// - defCount >= 3: slot tengah cycle lewat definisi interior.
int _sliceIndex(int slot, int slotCount, int defCount) {
  if (defCount == 1) return 0;
  if (slotCount == 1) return defCount ~/ 2;
  if (slot == 0) return 0;
  if (slot == slotCount - 1) return defCount - 1;
  if (defCount == 2) return defCount - 1;
  final interiorCount = defCount - 2;
  final interiorSlotIndex = (slot - 1) % interiorCount;
  return 1 + interiorSlotIndex;
}
