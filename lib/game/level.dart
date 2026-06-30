import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
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

  void _spawnObjects() {
    final spawnLayer =
        levelMap.tileMap.getLayer<ObjectGroup>('Spawnpoints');
    if (spawnLayer == null) return;

    final objects = spawnLayer.objects;

    // ── Pass 1: Gate, lalu pairing key dari Name ────────────────────
    final gateMap = <String, GateComponent>{};
    for (final sp in objects) {
      if (sp.class_ != 'Gate') continue;
      final gate = GateComponent(
        position: Vector2(sp.x, sp.y),
        size: Vector2(
          sp.width  > 0 ? sp.width.toDouble()  : 14,
          sp.height > 0 ? sp.height.toDouble() : 72,
        ),
      );
      add(gate);
      final key = _pairingKey(sp.name, 'gate');
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
          final key = _pairingKey(sp.name, 'lever');
          final targetGate = key != null ? gateMap[key] : null;
          add(LeverComponent(
            position: Vector2(sp.x, sp.y),
            onToggle: targetGate?.toggle,
          ));

        case 'Fountain':
          // Custom property "color" di Tiled: blue/red/green/yellow
          final colorStr =
              sp.properties.getValue<String>('color') ?? 'blue';
          final fountainColor = _parseFairyColor(colorStr);
          final fountain = FountainComponent(
            position: Vector2(sp.x, sp.y),
            requiredColor: fountainColor,
            onActivated: () {
              final key = _pairingKey(sp.name, 'fountain');
              final targetGate = key != null ? gateMap[key] : null;
              targetGate?.open();
            },
          );
          add(fountain);

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

  static String? _pairingKey(String name, String prefix) {
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
