import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:tiled/tiled.dart';

import '../game/components/player_component.dart';
import '../game/pairy_game.dart';

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

    _spawnObjects();

    await super.onLoad();
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
