# assets/maps/

Simpan file peta Tiled di sini (`.tmx` format XML).

## Konvensi penamaan
| File | Level |
|---|---|
| `level_1.tmx` | Level 1 (wajib MVP, PRD §6.8) |
| `level_2.tmx` | Level 2 (opsional, PRD §6.8) |

## Layer yang harus ada di setiap `.tmx`
(Lihat `lib/game/level/level_loader.dart` untuk dokumentasi lengkap)

| Layer | Tipe | Fungsi |
|---|---|---|
| `background` | Tile Layer | Dekorasi, tanpa collision |
| `ground` | Tile Layer | Tanah & platform solid |
| `spawns` | Object Layer | Titik spawn pemain (`name: "player"`) |
| `levers` | Object Layer | Posisi tuas |
| `gates` | Object Layer | Posisi gerbang, property `leverId` |
| `fountains` | Object Layer | Air mancur, property `color` |
| `fairies` | Object Layer | Peri, property `color` |
| `exit` | Object Layer | Pintu keluar (`name: "exit"`) |

## Cara kerja saat ini
`PairyWorld.buildDemoLevel()` masih menggunakan level hardcoded (tanpa Tiled).
Ganti isi fungsi tersebut dengan `LevelLoader.loadTiledLevel('level_1.tmx')`
setelah file `.tmx` siap.
