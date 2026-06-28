import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:tiled/tiled.dart';

import 'components/ground_component.dart';
import 'components/player_component.dart';
import 'pairy_game.dart';

class Level extends World with HasGameReference<PairyGame> {
  Level({required this.levelName});

  final String levelName;
  late TiledComponent levelMap;

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
    _spawnObjects();

    await super.onLoad();
  }

  /// Setiap tile di layer "Ground" dibuatkan GroundComponent (hitbox saja, tidak render).
  /// Dengan begitu PlayerComponent bisa collision dengan tile yang digambar di Tiled.
  void _addCollisions() {
    final groundLayer = levelMap.tileMap.getLayer<TileLayer>('Ground');
    if (groundLayer == null) return;

    final tileData = groundLayer.tileData;
    if (tileData == null) return;

    for (int y = 0; y < tileData.length; y++) {
      for (int x = 0; x < tileData[y].length; x++) {
        if (tileData[y][x].tile != 0) {
          add(GroundComponent(
            position: Vector2(x * 18.0, y * 18.0),
            size: Vector2.all(18),
          ));
        }
      }
    }
  }

  void _spawnObjects() {
    final spawnPointsLayer =
        levelMap.tileMap.getLayer<ObjectGroup>('Spawnpoints');
    if (spawnPointsLayer == null) return;

    for (final spawnPoint in spawnPointsLayer.objects) {
      switch (spawnPoint.class_) {
        case 'Player':
          final player = PlayerComponent(
            position: Vector2(spawnPoint.x, spawnPoint.y),
          );
          game.player = player;
          add(player);
          game.cam.follow(player);
        default:
          break;
      }
    }
  }

  Future<void> reload() async {
    removeAll(children.toList());
    game.player = null;
    await onLoad();
  }
}
