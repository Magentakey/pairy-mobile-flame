// level.dart
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

import '../components/exit_door_component.dart';
import '../components/button_component.dart';
import '../components/fairy_component.dart';
import '../components/fountain_component.dart';
import '../components/gate_component.dart';
import '../components/ground_component.dart';
import '../components/lever_component.dart';
import '../components/map_text_component.dart';
import '../components/moving_platform_component.dart';
import '../components/player_component.dart';
import '../components/stone_brick_component.dart';
import '../components/trigger_zone_component.dart';
import '../pairy_game.dart';
import '../../models/fairy_color.dart';

class Level extends World with HasGameReference<PairyGame> {
  Level({required this.levelName});

  final String levelName;
  late TiledComponent levelMap;
  final List<GroundComponent> groundComponents = [];

  // ── Render priority ──────────────────────────────────────────────
  // Urutan render (rendah ke tinggi): background/ground (0) < text (1)
  // < gate/platform/lever/fountain/exitDoor (2) < player (50) < fairy (100).
  static const int textPriority = 1;
  static const int interactivePriority = 2;
  static const int playerPriority = 50;

  /// Tinggi total map (px), dipakai untuk deteksi fall-death. Di-set
  /// ulang tiap kali level di-load.
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

    // Greedy row-merge: gabungkan tile solid bersebelahan dalam satu
    // baris jadi satu GroundComponent lebar, biar hitbox lebih sedikit.
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

    // Object yang share `name` yang sama masuk satu _TriggerGroup
    // (many-to-many, logika AND antar trigger).
    final groups = <String, _TriggerGroup>{};
    _TriggerGroup groupFor(String key) =>
        groups.putIfAbsent(key, _TriggerGroup.new);

    // Pass 1: Gate & MovingPlatform dibuat duluan supaya Lever/Fountain
    // di Pass 2 bisa langsung daftar ke grupnya.
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
              'tilemap_packed_industrilla_expansion.png',
          tileGrid: _getStringProp(sp, 'tileGrid') ?? '4,5,6',
        )..priority = interactivePriority;
        add(platform);
        final key = _keyOf(sp);
        if (key != null) groupFor(key).platforms.add(platform);
      } else if (sp.class_ == 'StoneBrick') {
        // StoneBrick bukan target trigger, murni solid fisik independen.
        final w = sp.width > 0 ? sp.width : 18.0;
        final h = sp.height > 0 ? sp.height : 18.0;
        add(
          StoneBrickComponent(
            position: Vector2(sp.x, sp.y),
            size: Vector2(w, h),
          )..priority = playerPriority,
        );
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
          )..priority = playerPriority;
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

        case 'StoneBrick':
          break;

        case 'Button':
          final key = _keyOf(sp);
          final btnW = sp.width > 0 ? sp.width : 20.0;
          final btnH = sp.height > 0 ? sp.height : 8.0;
          final mode = _getButtonMode(sp);
          final timerDuration = _getTimerDuration(sp);
          late final ButtonComponent button;
          button = ButtonComponent(
            position: Vector2(sp.x + btnW / 2, sp.y + btnH),
            mode: mode,
            timerDuration: timerDuration,
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
                getState: () => button.isOn,
                expected: _getActived(sp),
              ),
            );
          }
          add(button);

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
          // Invisible trigger zone, pairing lewat `name` seperti Lever/Fountain.
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
          // Konten teks dari property "content", `name` dipakai untuk pairing.
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
            // Tanpa pasangan trigger, tampil langsung tanpa animasi.
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
  // Nama kosong = objek berdiri sendiri, tidak ikut grup manapun.
  static String? _keyOf(TiledObject sp) {
    final name = sp.name.trim();
    return name.isEmpty ? null : name;
  }

  // `name` == "debugmode" (case-insensitive) pada Lever/Fountain/Trigger
  // manapun akan toggle `PairyGame.debugMode` alih-alih pairing biasa.
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

  // Property "mode" (string) di object Button: "plate"|"toggle"|"timer".
  // Fallback ke ButtonMode.plate kalau tidak dikenal/kosong.
  static ButtonMode _getButtonMode(TiledObject sp) {
    try {
      final raw = sp.properties.getValue<String>('mode')?.trim().toLowerCase();
      return ButtonMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => ButtonMode.plate,
      );
    } catch (_) {
      return ButtonMode.plate;
    }
  }

  // Property "timerDuration" (float), hanya relevan untuk mode timer.
  static double _getTimerDuration(TiledObject sp) {
    try {
      return sp.properties.getValue<double>('timerDuration') ?? 3.0;
    } catch (_) {
      return 3.0;
    }
  }

  // Isi teks object class_ "Text", dari property "content".
  static String _getTextContent(TiledObject sp) {
    try {
      return sp.properties.getValue<String>('content')?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  // Property "permanent" (bool, default true) di object Trigger.
  // true: sekali ON terkunci selamanya. false: OFF lagi begitu player keluar.
  static bool _getPermanent(TiledObject sp) {
    try {
      return sp.properties.getValue<bool>('permanent') ?? true;
    } catch (_) {
      return true;
    }
  }

  // Property "initialOpen" (bool, default false) di object Gate.
  static bool _getInitialOpen(TiledObject sp) {
    try {
      return sp.properties.getValue<bool>('initialOpen') ?? false;
    } catch (_) {
      return false;
    }
  }

  // Property "initialMoving" (bool, default true) di object MovingPlatform.
  static bool _getInitialMoving(TiledObject sp) {
    try {
      return sp.properties.getValue<bool>('initialMoving') ?? true;
    } catch (_) {
      return true;
    }
  }

  // Property string generik (tilesetImage/tileGrid) di Gate/MovingPlatform.
  // null kalau kosong, caller yang tentukan fallback default.
  static String? _getStringProp(TiledObject sp, String propName) {
    try {
      final value = sp.properties.getValue<String>(propName)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  // Property "actived" (bool, default true) di Lever/Fountain/Trigger:
  // nilai yang diharapkan supaya trigger ini "memenuhi syarat" AND grup.
  // false dipakai untuk bikin kondisi semacam NOT.
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

/// Kumpulan Gate/MovingPlatform (target) dan Lever/Fountain/Trigger
/// yang share `name` yang sama di Tiled (many-to-many).
///
/// Logika AND: target "aktif" kalau semua trigger match ekspektasinya
/// masing-masing ([_TriggerRef.expected], dari property `actived`).
/// State dihitung deterministik tiap [recompute]:
///   state = initialState XOR AND(semua trigger match ekspektasi)
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

    // Text selalu mulai tersembunyi, ikut hasil AND grup langsung
    // (tanpa XOR): allMatch true -> reveal, false -> hide.
    for (final text in texts) {
      allMatch ? text.reveal() : text.hide();
    }
  }
}

/// Satu trigger dalam grup. [getState] baca state real-time-nya,
/// [expected] adalah nilai yang harus dicapai (dari property `actived`).
class _TriggerRef {
  _TriggerRef({required this.getState, required this.expected});

  final bool Function() getState;
  final bool expected;
}