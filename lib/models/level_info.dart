/// Static metadata for a single level. Pair this with
/// `lib/game/level/level_loader.dart` once each level ships as a real
/// `.tmx` file exported from Tiled (https://www.mapeditor.org/).
class LevelInfo {
  const LevelInfo({
    required this.id,
    required this.name,
    required this.tmxPath,
  });

  final int id;
  final String name;

  /// Path under assets/maps/, e.g. 'assets/maps/level_1.tmx'.
  final String tmxPath;
}

/// PRD 6.8: MVP ships Level 1, with Level 2 optional if time allows.
const List<LevelInfo> kLevels = [
  LevelInfo(id: 1, name: 'Level 1', tmxPath: 'assets/maps/level_1.tmx'),
  // LevelInfo(id: 2, name: 'Level 2', tmxPath: 'assets/maps/level_2.tmx'),
];
