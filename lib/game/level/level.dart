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
import '../components/moving_platform_component.dart';
import '../components/player_component.dart';
import '../pairy_game.dart';
import '../../models/fairy_color.dart';

class Level extends World with HasGameReference<PairyGame> {
  Level({required this.levelName});

  final String levelName;
  late TiledComponent levelMap;
  final List<GroundComponent> groundComponents = [];

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

    // Pass 1: Gate — simpan ke map dengan pairing key
    final gateMap = <String, GateComponent>{};
    for (final sp in objects) {
      if (sp.class_ != 'Gate') continue;
      final w = sp.width > 0 ? sp.width.toDouble() : 14.0;
      final h = sp.height > 0 ? sp.height.toDouble() : 72.0;
      final gate = GateComponent(
        position: Vector2(sp.x + w / 2, sp.y + h),
        size: Vector2(w, h),
      );
      add(gate);
      final key = _stripPrefix(sp.name, 'gate');
      if (key != null) gateMap[key] = gate;
    }

    // Pass 2: sisanya
    for (final sp in objects) {
      switch (sp.class_) {
        case 'Player':
          final playerH = sp.height > 0 ? sp.height : 0.0;
          final player = PlayerComponent(
            position: Vector2(sp.x, sp.y + playerH - 30),
          );
          game.player = player;
          add(player);
          game.cam.follow(player);

        case 'ExitDoor':
          final exitW = sp.width > 0 ? sp.width : 26.0;
          final exitH = sp.height > 0 ? sp.height : 40.0;
          add(
            ExitDoorComponent(
              position: Vector2(sp.x + exitW / 2, sp.y + exitH),
            ),
          );

        case 'Gate':
          break;

        case 'MovingPlatform':
          final dirStr = sp.properties.getValue<String>('direction') ?? 'right';
          final dist = sp.properties.getValue<int>('distanceTiles') ?? 2;
          final spd = sp.properties.getValue<double>('speed') ?? 40.0;
          final w = sp.width > 0 ? sp.width : 54.0;
          final h = sp.height > 0 ? sp.height : 18.0;
          add(
            MovingPlatformComponent(
              position: Vector2(sp.x, sp.y),
              size: Vector2(w, h),
              direction: PlatformDirection.values.firstWhere(
                (d) => d.name == dirStr,
                orElse: () => PlatformDirection.right,
              ),
              distanceTiles: dist,
              speed: spd,
            ),
          );

        case 'Lever':
          final targetGate = gateMap[sp.name];
          final leverW = sp.width > 0 ? sp.width : 20.0;
          final leverH = sp.height > 0 ? sp.height : 24.0;
          add(
            LeverComponent(
              position: Vector2(sp.x + leverW / 2, sp.y + leverH),
              onToggle: targetGate?.toggle,
            ),
          );

        case 'Fountain':
          final fc = _getColor(sp);
          final targetGate = gateMap[sp.name];
          final founW = sp.width > 0 ? sp.width : 24.0;
          final founH = sp.height > 0 ? sp.height : 30.0;
          add(
            FountainComponent(
              position: Vector2(sp.x + founW / 2, sp.y + founH),
              requiredColor: _parseFairyColor(fc),
              onActivate: () => targetGate?.open(),
              onDeactivate: () => targetGate?.close(),
            ),
          );

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

        default:
          break;
      }
    }
  }

  static String _getColor(TiledObject sp) {
    try {
      return sp.properties.getValue<String>('color') ?? 'blue';
    } catch (_) {
      return 'blue';
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

  static String? _stripPrefix(String name, String prefix) {
    final lower = name.toLowerCase();
    if (lower.isEmpty || !lower.startsWith(prefix.toLowerCase())) return null;
    final key = name.substring(prefix.length);
    return key.isEmpty ? null : key;
  }

  Future<void> reload() async {
    groundComponents.clear();
    removeAll(children.toList());
    game.player = null;
    await onLoad();
  }
}
