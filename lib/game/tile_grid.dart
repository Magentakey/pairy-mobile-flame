import 'dart:ui';

import 'package:flame/components.dart';

/// Template kecil NxM (baris x kolom) tile-ID yang lalu di-"stretch"
/// untuk mengisi ukuran komponen sesungguhnya, dengan gaya 9-slice:
/// - baris pertama & terakhir = edge atas/bawah (tetap, tidak di-repeat)
/// - kolom pertama & terakhir = edge kiri/kanan (tetap, tidak di-repeat)
/// - baris/kolom DI ANTARANYA = interior, di-tile berulang (bukan
///   di-stretch/blur) untuk mengisi sisa ruang — supaya pixel art tetap
///   tajam walau ukuran komponennya beda-beda per instance. Kalau
///   interior lebih dari satu baris/kolom, dipakai bergantian (cycle)
///   supaya bisa ada variasi tile (mis. retak/noda acak di tengah gate).
///
/// Minimal butuh grid 1x1 (semua slot pakai 1 tile yang sama — ini yang
/// dipakai MovingPlatform versi lama sebelum ada left/mid/right), tapi
/// biasanya:
///   - 1 baris x 3 kolom → kiri/tengah(repeat)/kanan (mis. conveyor).
///   - 3 baris x 3 kolom → 9-slice penuh (mis. gate/pintu).
///
/// ## Format string — pakai tile ID (BUKAN col/row manual)
/// Baris dipisah `;`, ID dalam satu baris dipisah `,`. Tiap angka
/// adalah **tile ID lokal** tileset itu — angka yang sama persis dengan
/// yang muncul di panel "Properties" Tiled saat kamu klik satu tile di
/// panel Tilesets (field "ID"). Tidak perlu hitung manual kolom/baris;
/// tinggal klik tile yang mau dipakai di Tiled, salin angka ID-nya.
///
/// Contoh conveyor 1x3 (kiri/tengah/kanan):
///   "4,5,6"
/// Contoh gate 3x3:
///   "23,24,25;33,34,35;43,44,45"
///
/// ID → posisi piksel di-convert otomatis saat render, dengan cara
/// menghitung jumlah kolom tileset dari `image.width ~/ tileSize`
/// (persis bagaimana Tiled sendiri menghitung ID: `id = row * kolom +
/// col`), jadi tidak perlu properti tambahan untuk lebar tileset.
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

/// Render [grid] pakai tileset [image] (tiap tile berukuran [tileSize]
/// x [tileSize] piksel di source image), diskalakan mengisi
/// [targetSize] dengan aturan 9-slice + repeat interior (lihat
/// dokumentasi [TileGrid]).
///
/// Kolom tileset (dipakai buat convert ID → col/row) dihitung otomatis
/// dari `image.width ~/ tileSize` — sama seperti cara Tiled menomori ID
/// tile di file .tsx-nya, jadi ID yang kamu salin dari panel Properties
/// Tiled akan selalu cocok tanpa perlu properti "kolom tileset" manual.
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

/// Map index slot render ([slot], dari 0..slotCount-1) ke index
/// baris/kolom di grid definisi ([defCount] total definisi tersedia
/// pada axis itu):
/// - defCount == 1 → semua slot pakai definisi itu-itu saja.
/// - slotCount == 1 → pakai definisi tengah (biar tidak berat sebelah
///   ke salah satu edge, mis. platform yang cuma 1 tile lebar).
/// - slot pertama  → selalu definisi pertama (edge awal).
/// - slot terakhir → selalu definisi terakhir (edge akhir).
/// - defCount == 2 tapi slotCount > 2 → tidak ada interior
///   didefinisikan; slot tengah fallback pakai definisi terakhir biar
///   tidak index-out-of-range.
/// - defCount >= 3 → slot di tengah cycle lewat definisi interior
///   (index 1..defCount-2).
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