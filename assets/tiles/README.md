# assets/tiles/

Simpan file tileset di sini — format `.png` (gambar) dan `.tsj`/`.tsx` (metadata Tiled).

## Rekomendasi tileset
**Kenney Pixel Platformer** — https://kenney.nl/assets/pixel-platformer
- Ukuran tile: 18 × 18 px (perlu di-*crop* atau sesuaikan tile size di Tiled)
- Lisensi: CC0

**Kenney Platformer Art Deluxe** — https://kenney.nl/assets/platformer-art-deluxe
- 930 aset termasuk tile tanah, batu, rerumputan
- CC0

## Catatan Tiled
- Tile size yang digunakan proyek ini: **16 × 16 px** (lihat `LevelLoader.loadTiledLevel` default)
- Jika tileset menggunakan ukuran berbeda, sesuaikan parameter `tileSize` saat memanggil `LevelLoader`
- Simpan tileset sebagai `.tsx` agar bisa di-share antar beberapa `.tmx`
