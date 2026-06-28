# assets/images/environment/

Simpan sprite objek dunia game di sini: tuas (lever), gerbang (gate), pintu keluar,
air mancur (fountain), dan dekorasi lainnya.

## Rekomendasi aset
- **Kenney Pixel Platformer** — https://kenney.nl/assets/pixel-platformer
  Berisi: door, switch, platform pieces — CC0, gratis

- Cari di itch.io: https://itch.io/game-assets/tag-puzzle-platformer
  Filter: "door", "switch", "gate" — banyak pack gratis atau murah

## File yang dibutuhkan (MVP)
| File | Keterangan |
|---|---|
| `lever_off.png` | Tuas posisi mati |
| `lever_on.png`  | Tuas posisi hidup |
| `gate_closed.png` | Gerbang tertutup |
| `gate_open.png`   | Gerbang terbuka |
| `fountain_inactive.png` | Air mancur belum aktif |
| `fountain_active.png`   | Air mancur aktif |
| `exit_door.png` | Pintu keluar |

Untuk MVP, semua objek sudah digambar secara programatik di masing-masing `render()`.
