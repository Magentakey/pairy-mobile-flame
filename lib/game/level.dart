import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import 'package:flame_tiled/flame_tiled.dart';

import 'components/exit_door_component.dart';
import 'components/fairy_component.dart';
import 'components/fountain_component.dart';
import 'components/gate_component.dart';
import 'components/ground_component.dart';
import 'components/lever_component.dart';
import 'components/player_component.dart';
import 'pairy_game.dart';
import '../models/fairy_color.dart';

class Level extends World with HasGameReference<PairyGame> {
  Level({required this.levelName});

  final String levelName;
  late TiledComponent levelMap;
  final List<GroundComponent> groundComponents = [];

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

    final mapWidth = groundLayer.width ?? 36;
    for (int i = 0; i < data.length; i++) {
      if (data[i] != 0) {
        final x = i % mapWidth;
        final y = i ~/ mapWidth;
        final ground = GroundComponent(
          position: Vector2(x * 18.0, y * 18.0),
          size: Vector2.all(18),
        );
        groundComponents.add(ground);
        add(ground);
      }
    }
  }

  /// ── Konvensi penamaan pairing di Tiled ────────────────────────────
  /// Gate diberi nama dengan prefix "gate" + nama target persis:
  ///   Lever "lever1"    ↔ Gate "gatelever1"
  ///   Fountain "fairy1" ↔ Gate "gatefairy1"
  ///
  /// Nama gate generik seperti "gate1" sengaja TIDAK akan match apa pun
  /// (tidak ada lever/fountain bernama "1") — jadi ambiguitas lama
  /// (gate1 dipakai bareng fairy1 & lever1) otomatis tidak mungkin terjadi.
  void _spawnObjects() {
    final spawnLayer =
        levelMap.tileMap.getLayer<ObjectGroup>('Spawnpoints');
    if (spawnLayer == null) return;

    final objects = spawnLayer.objects;

    // ── Pass 1: semua Gate dulu, simpan ke map by pairing key ───────
    final gateMap = <String, GateComponent>{};
    for (final sp in objects) {
      if (sp.class_ != 'Gate') continue;

      final w = sp.width  > 0 ? sp.width.toDouble()  : 14.0;
      final h = sp.height > 0 ? sp.height.toDouble() : 72.0;
      final gate = GateComponent(
        // anchor bottomCenter — geser dari rect Tiled (top-left based)
        // ke titik bottom-center supaya visual tetap pas di posisi yang digambar
        position: Vector2(sp.x + w / 2, sp.y + h),
        size: Vector2(w, h),
      );
      add(gate);

      final key = _stripPrefix(sp.name, 'gate');
      if (key != null) gateMap[key] = gate;
    }

    // ── Pass 2: sisanya — Player, ExitDoor, Lever, Fountain, Fairy ──
    for (final sp in objects) {
      switch (sp.class_) {
        case 'Player':
          final player = PlayerComponent(
            position: Vector2(sp.x, sp.y - 34),
          );
          game.player = player;
          add(player);
          game.cam.follow(player);

        case 'ExitDoor':
          add(ExitDoorComponent(position: Vector2(sp.x, sp.y)));

        case 'Gate':
          break; // sudah dibuat di pass 1

        case 'Lever':
          // Nama lever dipakai langsung sebagai pairing key, mis. "lever1"
          final targetGate = gateMap[sp.name];
          add(LeverComponent(
            position: Vector2(sp.x, sp.y),
            onToggle: targetGate?.toggle,
          ));

        case 'Fountain':
          final colorStr =
              sp.properties.getValue<String>('color') ?? 'blue';
          // Nama fountain dipakai langsung sebagai pairing key, mis. "fairy1"
          final targetGate = gateMap[sp.name];
          add(FountainComponent(
            position: Vector2(sp.x, sp.y),
            requiredColor: _parseFairyColor(colorStr),
            onActivated: () => targetGate?.open(),
          ));

        case 'Fairy':
          final colorStr =
              sp.properties.getValue<String>('color') ?? 'blue';
          add(FairyComponent(
            position: Vector2(sp.x, sp.y),
            color: _parseFairyColor(colorStr),
          ));

        default:
          break;
      }
    }
  }

  static FairyColor _parseFairyColor(String value) {
    switch (value.toLowerCase()) {
      case 'red':    return FairyColor.red;
      case 'green':  return FairyColor.green;
      case 'yellow': return FairyColor.yellow;
      default:       return FairyColor.blue;
    }
  }

  /// "gatelever1".substring("gate".length) → "lever1"
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
