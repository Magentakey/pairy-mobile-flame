import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

/// Loads a Tiled `.tmx` map file and returns the [TiledComponent] ready
/// to be added to [PairyWorld].
///
/// ## Tiled project conventions
///
/// ### Tile layers
/// | Layer name | Purpose |
/// |---|---|
/// | `background` | Purely decorative tiles (no collision) |
/// | `ground`     | Solid tiles — the engine reads this layer to generate [GroundComponent]s |
///
/// ### Object layers
/// | Layer name | Object type / property | Meaning |
/// |---|---|---|
/// | `spawns`    | object named `"player"` | Player start position |
/// | `levers`    | any object | One [LeverComponent] per object; use `id` in object name |
/// | `gates`     | custom property `leverId` (string) | Links gate → lever by matching name |
/// | `fountains` | custom property `color` (`"blue"/"red"/"green"/"yellow"`) | Fountain required color |
/// | `fairies`   | custom property `color` | Fairy color |
/// | `exit`      | object named `"exit"` | Single [ExitDoorComponent] |
///
/// ### Recommended settings in Tiled
/// - Map size: infinite or large enough for the level
/// - Tile size: 16 × 16 px (matches the default [tileSize] param below)
/// - Orientation: Orthogonal
/// - Export as: `.tmx` (XML format), saved to `assets/maps/`
/// - Save tileset(s) as `.tsj` / `.tsx` embedded or adjacent to the `.tmx`
///
/// ## Usage
/// ```dart
/// final mapComponent = await LevelLoader.loadTiledLevel('level_1.tmx');
/// world.add(mapComponent);
/// ```
///
/// After adding, iterate `mapComponent.tileMap` object layers to spawn
/// the appropriate game components from the object coordinates.
class LevelLoader {
  LevelLoader._(); // static-only utility class

  /// Loads [fileName] from `assets/maps/` and returns the rendered
  /// [TiledComponent].
  ///
  /// [tileSize] must match the tile size set in the Tiled project
  /// (default 16 px). Adjust if using a different tileset.
  static Future<TiledComponent> loadTiledLevel(
    String fileName, {
    double tileSize = 16,
  }) async {
    final component = await TiledComponent.load(
      fileName,
      Vector2.all(tileSize),
    );
    return component;
  }
}
