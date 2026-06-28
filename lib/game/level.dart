import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

class Level extends World {
  late TiledComponent levelMap;

  @override
  Future<void> onLoad() async {
    // Cari gambar tileset di assets/tiles/ (bukan assets/images/)
    // sehingga path di TSX cukup "tilemap_packed.png" tanpa prefix folder
    final images = Images(prefix: 'assets/tiles/');

    levelMap = await TiledComponent.load(
      'level-01.tmx',
      Vector2.all(18),
      images: images,
    );
    add(levelMap);

    await super.onLoad();
  }

  Future<void> reload() async {
    removeAll(children.toList());
    await onLoad();
  }
}
