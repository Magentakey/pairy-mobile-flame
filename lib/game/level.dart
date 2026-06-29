import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';

import 'components/exit_door_component.dart';
import 'components/gate_component.dart';
import 'components/ground_component.dart';
import 'components/lever_component.dart';
import 'components/player_component.dart';
import 'pairy_game.dart';

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

    // ── Pass 1: buat semua Gate, simpan di Map pakai key dari Name ──
    // Konvensi Name: "gate1", "gate2", "gateA", dll.
    // Key = bagian setelah "gate" → "1", "2", "A"
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

      // Ambil pairing key dari nama, misal "gate1" → key "1"
      final key = _pairingKey(sp.name, 'gate');
      if (key != null) gateMap[key] = gate;
    }

    // ── Pass 2: spawn semua objek lainnya ────────────────────────────
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
          add(ExitDoorComponent(position: Vector2(sp.x, sp.y - 40)));

        case 'Gate':
          break; // sudah dibuat di pass 1

        case 'Lever':
          // Ambil pairing key, misal "lever1" → key "1" → cocokkan ke gateMap
          final key = _pairingKey(sp.name, 'lever');
          final targetGate = key != null ? gateMap[key] : null;

          add(LeverComponent(
            position: Vector2(sp.x, sp.y),
            onToggle: targetGate?.toggle,
          ));

        default:
          break;
      }
    }
  }

  /// Ambil suffix dari name: "gate1" → "1", "lever_A" → "_A".
  /// Return null jika name kosong atau tidak mengandung prefix.
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
