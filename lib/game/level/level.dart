// level.dart
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

import '../components/exit_door_component.dart';
import '../components/fairy_component.dart';
import '../components/fountain_component.dart';
import '../components/gate_component.dart';
import '../components/ground_component.dart';
import '../components/lever_component.dart';
import '../components/map_text_component.dart';
import '../components/moving_platform_component.dart';
import '../components/player_component.dart';
import '../components/trigger_zone_component.dart';
import '../pairy_game.dart';
import '../../models/fairy_color.dart';

class Level extends World with HasGameReference<PairyGame> {
  Level({required this.levelName});

  final String levelName;
  late TiledComponent levelMap;
  final List<GroundComponent> groundComponents = [];

  // ── Render priority ──────────────────────────────────────────────
  // Background (TiledComponent) & GroundComponent dibiarkan di priority
  // default (0). MapTextComponent sengaja diberi priority di ATAS itu
  // (textPriority) tapi di BAWAH semua komponen interaktif lain
  // (interactivePriority), supaya text map SELALU kalah render dari
  // player/gate/platform/lever/fountain/exitDoor/fairy, dan HANYA menang
  // dari background & ground layer. Tanpa priority eksplisit ini,
  // urutan render antar komponen priority-0 cuma ngikutin urutan
  // add()/child list, yang tidak dijamin konsisten (apalagi ada
  // komponen yang di-add lewat pass terpisah / async onLoad).
  static const int textPriority = 1;
  static const int interactivePriority = 2;
  // Fairy pakai priority 100 sendiri (lihat FairyComponent) — selalu
  // paling atas dari semuanya, termasuk di atas interactivePriority ini.

  /// Tinggi total map dalam pixel, dipakai buat deteksi player jatuh
  /// keluar map (fall-death). Di-set ulang tiap kali level di-load,
  /// jadi otomatis ngikutin ukuran map masing-masing level meski beda-beda.
  double heightPx = 0;

  @override
  Future<void> onLoad() async {
    final images = Images(prefix: 'assets/tiles/');
    levelMap = await TiledComponent.load(
      '$levelName.tmx',
      Vector2.all(18),
      images: images,
    );
    add(levelMap);
    _addCollisions();
    await super.onLoad();
  }

  @override
  void onMount() {
    super.onMount();
    _spawnObjects();
  }

  void _addCollisions() {
    final groundLayer = levelMap.tileMap.getLayer<TileLayer>('Ground');
    if (groundLayer == null) return;
    final data = groundLayer.data;
    if (data == null || data.isEmpty) return;

    const tileSize = 18.0;
    final mapWidth = groundLayer.width;
    final mapHeight = groundLayer.height;
    heightPx = mapHeight * tileSize;

    // Greedy row-merge: gabungkan tile solid yang bersebelahan secara
    // horizontal dalam satu baris jadi SATU GroundComponent lebar,
    // bukan 1 component per tile. Blok tanah lebar → jauh lebih sedikit
    // hitbox & jauh lebih ringan di loop collision player tiap frame.
    for (int y = 0; y < mapHeight; y++) {
      int x = 0;
      while (x < mapWidth) {
        final index = y * mapWidth + x;
        if (data[index] == 0) {
          x++;
          continue;
        }

        // Cari berapa tile berturut-turut yang solid ke kanan.
        final runStart = x;
        while (x < mapWidth && data[y * mapWidth + x] != 0) {
          x++;
        }
        final runLength = x - runStart;

        final ground = GroundComponent(
          position: Vector2(runStart * tileSize, y * tileSize),
          size: Vector2(runLength * tileSize, tileSize),
        );
        groundComponents.add(ground);
        add(ground);
      }
    }
  }

  void _spawnObjects() {
    final spawnLayer = levelMap.tileMap.getLayer<ObjectGroup>('Spawnpoints');
    if (spawnLayer == null) return;

    final objects = spawnLayer.objects;

    // Semua Gate/Platform yang share nama yang sama dengan semua
    // Lever/Fountain yang share nama yang sama itu masuk satu _TriggerGroup.
    // Relasinya many-to-many: 1 nama bisa punya banyak target & banyak
    // trigger sekaligus, dan logikanya AND — target baru berubah state
    // kalau SEMUA trigger dengan nama itu dalam kondisi "on".
    final groups = <String, _TriggerGroup>{};
    _TriggerGroup groupFor(String key) =>
        groups.putIfAbsent(key, _TriggerGroup.new);

    // Pass 1: Gate & MovingPlatform — dibuat & di-add duluan supaya
    // Lever/Fountain di Pass 2 sudah bisa daftar sebagai trigger grupnya.
    for (final sp in objects) {
      if (sp.class_ == 'Gate') {
        final w = sp.width > 0 ? sp.width.toDouble() : 14.0;
        final h = sp.height > 0 ? sp.height.toDouble() : 72.0;
        final initialOpen = _getInitialOpen(sp);
        final gate = GateComponent(
          position: Vector2(sp.x + w / 2, sp.y + h),
          size: Vector2(w, h),
          initialOpen: initialOpen,
          tilesetImage: _getStringProp(sp, 'tilesetImage'),
          tileGrid: _getStringProp(sp, 'tileGrid'),
        )..priority = interactivePriority;
        add(gate);
        final key = _keyOf(sp);
        if (key != null) groupFor(key).gates.add(gate);
      } else if (sp.class_ == 'MovingPlatform') {
        final dirStr = sp.properties.getValue<String>('direction') ?? 'right';
        final dist = sp.properties.getValue<int>('distanceTiles') ?? 2;
        final spd = sp.properties.getValue<double>('speed') ?? 40.0;
        final initialMoving = _getInitialMoving(sp);
        final w = sp.width > 0 ? sp.width : 54.0;
        final h = sp.height > 0 ? sp.height : 18.0;
        final platform = MovingPlatformComponent(
          position: Vector2(sp.x, sp.y),
          size: Vector2(w, h),
          direction: PlatformDirection.values.firstWhere(
            (d) => d.name == dirStr,
            orElse: () => PlatformDirection.right,
          ),
          distanceTiles: dist,
          speed: spd,
          initialMoving: initialMoving,
          tilesetImage:
              _getStringProp(sp, 'tilesetImage') ??
              'tilemap_packed_industrilla expansion.png',
          tileGrid: _getStringProp(sp, 'tileGrid') ?? '4,5,6',
        )..priority = interactivePriority;
        add(platform);
        final key = _keyOf(sp);
        if (key != null) groupFor(key).platforms.add(platform);
      }
    }

    // Pass 2: sisanya
    for (final sp in objects) {
      switch (sp.class_) {
        case 'Player':
          final playerH = sp.height > 0 ? sp.height : 0.0;
          final player = PlayerComponent(
            position: Vector2(
              sp.x,
              sp.y + playerH - PlayerComponent.hitboxSize.y,
            ),
          )..priority = interactivePriority;
          game.player = player;
          add(player);
          game.cam.follow(player);

        case 'ExitDoor':
          final exitW = sp.width > 0 ? sp.width : 26.0;
          final exitH = sp.height > 0 ? sp.height : 40.0;
          add(
            ExitDoorComponent(position: Vector2(sp.x + exitW / 2, sp.y + exitH))
              ..priority = interactivePriority,
          );

        case 'Gate':
          break;

        case 'MovingPlatform':
          break;

        case 'Lever':
          final key = _keyOf(sp);
          final leverW = sp.width > 0 ? sp.width : 20.0;
          final leverH = sp.height > 0 ? sp.height : 24.0;
          late final LeverComponent lever;
          lever = LeverComponent(
            position: Vector2(sp.x + leverW / 2, sp.y + leverH),
            onToggle: key == null
                ? null
                : () {
                    groupFor(key).recompute();
                    _maybeToggleDebugMode(key);
                  },
          )..priority = interactivePriority;
          if (key != null) {
            groupFor(key).triggers.add(
              _TriggerRef(
                getState: () => lever.isOn,
                expected: _getActived(sp),
              ),
            );
          }
          add(lever);

        case 'Fountain':
          final fc = _getColor(sp);
          final key = _keyOf(sp);
          final founW = sp.width > 0 ? sp.width : 24.0;
          final founH = sp.height > 0 ? sp.height : 30.0;
          late final FountainComponent fountain;
          fountain = FountainComponent(
            position: Vector2(sp.x + founW / 2, sp.y + founH),
            requiredColor: _parseFairyColor(fc),
            onActivationChanged: key == null
                ? null
                : () {
                    groupFor(key).recompute();
                    _maybeToggleDebugMode(key);
                  },
          )..priority = interactivePriority;
          if (key != null) {
            groupFor(key).triggers.add(
              _TriggerRef(
                getState: () => fountain.isActivated,
                expected: _getActived(sp),
              ),
            );
          }
          add(fountain);

        case 'Fairy':
          final fc = _getColor(sp);
          final fairyW = sp.width > 0 ? sp.width : 20.0;
          final fairyH = sp.height > 0 ? sp.height : 20.0;
          add(
            FairyComponent(
              position: Vector2(sp.x + fairyW / 2, sp.y + fairyH / 2),
              color: _parseFairyColor(fc),
            ),
          );

        case 'Trigger':
          // Invisible trigger zone — pairing lewat `name` persis seperti
          // Lever/Fountain. Bisa jadi trigger untuk Gate/MovingPlatform
          // (lewat _TriggerGroup.gates/platforms) SEKALIGUS memunculkan
          // MapText (lewat _TriggerGroup.texts), asal share `name` yang
          // sama.
          final triggerKey = _keyOf(sp);
          final triggerW = sp.width > 0 ? sp.width : 20.0;
          final triggerH = sp.height > 0 ? sp.height : 20.0;
          late final TriggerZoneComponent trigger;
          trigger = TriggerZoneComponent(
            position: Vector2(sp.x, sp.y),
            size: Vector2(triggerW, triggerH),
            onToggle: triggerKey == null
                ? null
                : () {
                    groupFor(triggerKey).recompute();
                    _maybeToggleDebugMode(triggerKey);
                  },
            permanent: _getPermanent(sp),
          );
          if (triggerKey != null) {
            groupFor(triggerKey).triggers.add(
              _TriggerRef(
                getState: () => trigger.isOn,
                expected: _getActived(sp),
              ),
            );
          }
          add(trigger);

        case 'Text':
          // Konten teks SENGAJA diambil dari custom property "content",
          // bukan dari `name` object — `name` di sini dipakai untuk
          // pairing ke trigger zone (sama seperti Gate/Platform/Lever/
          // Fountain), supaya tidak perlu placeholder aneh di `name`.
          final content = _getTextContent(sp);
          if (content.isEmpty) break;
          final textW = sp.width > 0 ? sp.width : 0.0;
          final textH = sp.height > 0 ? sp.height : 0.0;
          final mapText = MapTextComponent(
            text: content,
            position: Vector2(sp.x + textW / 2, sp.y + textH / 2),
          )..priority = textPriority;
          final textKey = _keyOf(sp);
          if (textKey != null) {
            groupFor(textKey).texts.add(mapText);
          } else {
            // Tidak punya pasangan trigger sama sekali → tampil langsung
            // tanpa animasi, perilaku lama sebagai label statis biasa.
            mapText.showInstantly();
          }
          add(mapText);

        default:
          break;
      }
    }
  }

  // Key pairing sekarang langsung pakai `name` object di Tiled apa adanya
  // (tanpa prefix "gate"/"platform" lagi) — bebas mau diisi "1", "a",
  // "iamunique", dst. Nama kosong = objek berdiri sendiri (tidak ikut
  // grup manapun, murni pakai initialOpen/initialMoving-nya sendiri).
  static String? _keyOf(TiledObject sp) {
    final name = sp.name.trim();
    return name.isEmpty ? null : name;
  }

  // Nama khusus (case-insensitive) buat lever/fountain/trigger invisible
  // yang fungsinya BUKAN pairing gate/platform biasa, tapi nyala/matiin
  // `PairyGame.debugMode` (outline hitbox semua komponen collision).
  // Dipanggil dari onToggle/onActivationChanged Lever, Fountain, DAN
  // Trigger — jadi bisa dipasang sebagai objek jenis apa pun di Tiled,
  // asal `name`-nya "debugmode".
  void _maybeToggleDebugMode(String? key) {
    if (key != null && key.toLowerCase() == 'debugmode') {
      game.toggleDebugMode();
    }
  }

  static String _getColor(TiledObject sp) {
    try {
      return sp.properties.getValue<String>('color') ?? 'blue';
    } catch (_) {
      return 'blue';
    }
  }

  // Isi teks untuk object class_ "Text", diambil dari custom property
  // "content" (bukan `name`) — lihat komentar di case 'Text' di atas.
  static String _getTextContent(TiledObject sp) {
    try {
      return sp.properties.getValue<String>('content')?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  // Custom property boolean di Tiled buat object Trigger, misal:
  // Custom Properties → name: permanent, type: bool, default: true
  // true (default): sekali kesentuh, trigger terkunci ON selamanya —
  // player tidak perlu tetap berdiri di zona itu.
  // false: trigger cuma ON selama player masih ada di dalam zona,
  // begitu keluar langsung balik OFF (dan target ikut balik state awal).
  static bool _getPermanent(TiledObject sp) {
    try {
      return sp.properties.getValue<bool>('permanent') ?? true;
    } catch (_) {
      return true;
    }
  }

  // Custom property boolean di Tiled buat object Gate, misal:
  // Custom Properties → name: initialOpen, type: bool, default: false
  // Kalau tidak diisi, default-nya false (gate tertutup di awal),
  // sama seperti behavior lama.
  static bool _getInitialOpen(TiledObject sp) {
    try {
      return sp.properties.getValue<bool>('initialOpen') ?? false;
    } catch (_) {
      return false;
    }
  }

  // Custom property boolean di Tiled buat object MovingPlatform, misal:
  // Custom Properties → name: initialMoving, type: bool, default: true
  // Kalau tidak diisi, default-nya true (platform bergerak di awal),
  // dan tetap true walau tidak punya pasangan lever/fountain sama sekali.
  static bool _getInitialMoving(TiledObject sp) {
    try {
      return sp.properties.getValue<bool>('initialMoving') ?? true;
    } catch (_) {
      return true;
    }
  }

  // Custom property string generik di Tiled, dipakai buat `tilesetImage`
  // & `tileGrid` baik di object Gate maupun MovingPlatform. null kalau
  // property tidak diisi / kosong — caller yang menentukan fallback
  // default masing-masing (Gate: null → placeholder lama; MovingPlatform
  // → fallback ke tileset & grid conveyor lama).
  static String? _getStringProp(TiledObject sp, String propName) {
    try {
      final value = sp.properties.getValue<String>(propName)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  // Custom property boolean di Lever/Fountain, misal:
  // Custom Properties → name: actived, type: bool, default: true
  // Ini bukan "apakah trigger sedang on/off", tapi ekspektasi yang harus
  // dicapai supaya trigger ini dianggap memenuhi syarat AND grup:
  // - actived=true (default): trigger ini harus dalam kondisi ON
  //   (lever nyala / ada fairy warna cocok di fountain) baru "memenuhi syarat".
  // - actived=false: kebalikannya — trigger ini justru harus OFF baru
  //   "memenuhi syarat" (dipakai buat bikin kondisi semacam NOT).
  static bool _getActived(TiledObject sp) {
    try {
      return sp.properties.getValue<bool>('actived') ?? true;
    } catch (_) {
      return true;
    }
  }

  static FairyColor _parseFairyColor(String value) {
    switch (value.toLowerCase()) {
      case 'red':
        return FairyColor.red;
      case 'green':
        return FairyColor.green;
      case 'yellow':
        return FairyColor.yellow;
      default:
        return FairyColor.blue;
    }
  }

  Future<void> reload() async {
    groundComponents.clear();
    removeAll(children.toList());
    game.player = null;
    await onLoad();
  }
}

/// Kumpulan Gate/MovingPlatform (target) dan Lever/Fountain (trigger)
/// yang share nama object yang sama di Tiled. Relasinya many-to-many:
/// 1 grup bisa punya banyak target dan banyak trigger sekaligus.
///
/// Logikanya AND: target baru dianggap "aktif" kalau SEMUA trigger
/// dalam grup itu match dengan ekspektasi masing-masing (lihat
/// [_TriggerRef.expected], dari custom property `actived` di Tiled,
/// default true). Kalau satu saja tidak match, target tetap di state
/// awalnya (belum berubah).
///
/// Contoh: 2 lever nama "a" — lever1 `actived=true` (default), lever2
/// `actived=false`. AND baru terpenuhi kalau lever1 ON dan lever2 OFF.
///
/// State target dihitung deterministik tiap [recompute] dipanggil:
///   state = initialState XOR AND(semua trigger match ekspektasinya)
/// — bukan flip/toggle biasa, supaya hasilnya konsisten walau
/// triggernya banyak dan berubah gantian.
class _TriggerGroup {
  final List<GateComponent> gates = [];
  final List<MovingPlatformComponent> platforms = [];
  final List<MapTextComponent> texts = [];

  final List<_TriggerRef> triggers = [];

  void recompute() {
    final allMatch =
        triggers.isNotEmpty &&
        triggers.every((t) => t.getState() == t.expected);

    for (final gate in gates) {
      final shouldBeOpen = gate.initialOpen ^ allMatch;
      shouldBeOpen ? gate.open() : gate.close();
    }

    for (final platform in platforms) {
      final shouldMove = platform.initialMoving ^ allMatch;
      shouldMove ? platform.start() : platform.stop();
    }

    // Text tidak punya konsep "initialOpen" seperti gate/platform — dia
    // selalu mulai tersembunyi, dan langsung mengikuti hasil AND grup
    // apa adanya (tanpa XOR): allMatch true → reveal, false → hide lagi.
    for (final text in texts) {
      allMatch ? text.reveal() : text.hide();
    }
  }
}

/// Satu trigger (Lever/Fountain) dalam grup.
/// [getState] baca state real-time-nya (lever.isOn / fountain.isActivated).
/// [expected] adalah nilai yang harus dicapai supaya trigger ini dianggap
/// "memenuhi syarat" AND — datang dari custom property `actived` di Tiled
/// pada object Lever/Fountain tsb (default true).
class _TriggerRef {
  _TriggerRef({required this.getState, required this.expected});

  final bool Function() getState;
  final bool expected;
}
