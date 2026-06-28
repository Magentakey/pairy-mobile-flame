import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

class Level extends World {
  late TiledComponent levelMap;

  @override
  Future<void> onLoad() async {
    levelMap = await TiledComponent.load(
      'level-01.tmx',
      Vector2.all(18),
    );
    add(levelMap);

    await super.onLoad();
  }
}
