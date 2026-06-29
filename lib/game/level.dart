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

    // ── Kumpulkan gate dulu sebelum lever ────────────────────────────
    final gates = <GateComponent>[];
    final leverObjects = <TiledObject>[];

    for (final sp in spawnLayer.objects) {
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
          // Buat ukuran gate dari objek Tiled (gambar rectangle di Tiled)
          final gate = GateComponent(
            position: Vector2(sp.x, sp.y),
            size: Vector2(
              sp.width  > 0 ? sp.width.toDouble()  : 14,
              sp.height > 0 ? sp.height.toDouble() : 72,
            ),
          );
          gates.add(gate);
          add(gate);

        case 'Lever':
          leverObjects.add(sp);

        default:
          break;
      }
    }

    // ── Spawn lever, wire ke gate berdasarkan urutan ─────────────────
    // Lever ke-1 → Gate ke-1, Lever ke-2 → Gate ke-2, dst.
    for (int i = 0; i < leverObjects.length; i++) {
      final sp = leverObjects[i];
      final targetGate = i < gates.length ? gates[i] : null;

      add(LeverComponent(
        position: Vector2(sp.x, sp.y - 24),
        onToggle: targetGate?.toggle,
      ));
    }
  }

  Future<void> reload() async {
    groundComponents.clear();
    removeAll(children.toList());
    game.player = null;
    await onLoad();
  }
}
