import 'package:flame/components.dart';
import 'package:flame/game.dart';

import 'components/exit_door_component.dart';
import 'components/fairy_component.dart';
import 'components/fountain_component.dart';
import 'components/gate_component.dart';
import 'components/ground_component.dart';
import 'components/lever_component.dart';
import 'components/player_component.dart';
import 'pairy_game.dart';
import '../models/fairy_color.dart';

/// The Flame [World] that holds every game object for Pairy.
///
/// [buildDemoLevel] hand-places a simple staircase layout that matches the
/// wireframe sketch (PRD §14 wireframe, "Gameplay Screen" panel).
/// Once you have Tiled maps ready, replace the body of [buildDemoLevel]
/// with a call to `LevelLoader.loadTiledLevel(...)` — see
/// `lib/game/level/level_loader.dart` for the conventions.
///
/// Virtual canvas: 480 × 270 px. All positions here use that coordinate
/// system. Anchor.topLeft is the default for all components.
class PairyWorld extends World with HasGameReference<PairyGame> {
  late PlayerComponent player;

  @override
  Future<void> onLoad() async {
    await buildDemoLevel();
  }

  Future<void> buildDemoLevel() async {
    // Clear any previous objects (e.g. on retry).
    removeAll(children.toList());

    // ── Ground / Staircase platforms ──────────────────────────────────
    // A simple 4-step staircase going left → right, rising in height,
    // plus a wide floor so the player always has ground to land on.

    // Wide floor at the bottom
    final floor = GroundComponent(
      position: Vector2(0, 246),
      size: Vector2(480, 24),
    );

    // Step 1 (lowest)
    final step1 = GroundComponent(
      position: Vector2(80, 214),
      size: Vector2(70, 12),
    );

    // Step 2
    final step2 = GroundComponent(
      position: Vector2(170, 182),
      size: Vector2(70, 12),
    );

    // Step 3
    final step3 = GroundComponent(
      position: Vector2(260, 150),
      size: Vector2(70, 12),
    );

    // Elevated platform at the right — goal area
    final goalPlatform = GroundComponent(
      position: Vector2(360, 118),
      size: Vector2(120, 12),
    );

    // ── Lever + Gate ─────────────────────────────────────────────────
    // Gate blocks the path between step 2 and step 3.
    final gate = GateComponent(
      position: Vector2(248, 134),
      size: Vector2(10, 48),
    );

    // Lever is on step 1, wired to toggle the gate.
    final lever = LeverComponent(
      position: Vector2(110, 184),
      onToggle: gate.toggle,
    );

    // ── Fountain + Fairy ─────────────────────────────────────────────
    // A blue fountain on step 3 that opens the gate when activated by
    // the blue fairy.
    final fountain = FountainComponent(
      position: Vector2(290, 126),
      requiredColor: FairyColor.blue,
      onActivated: gate.open,
    );

    // The blue fairy starts hovering above the floor on the left side.
    final fairy = FairyComponent(
      position: Vector2(44, 200),
      color: FairyColor.blue,
    );

    // ── Exit door ────────────────────────────────────────────────────
    final exitDoor = ExitDoorComponent(position: Vector2(420, 78));

    // ── Player ───────────────────────────────────────────────────────
    player = PlayerComponent(position: Vector2(20, 210));

    addAll([
      floor,
      step1,
      step2,
      step3,
      goalPlatform,
      gate,
      lever,
      fountain,
      fairy,
      exitDoor,
      player,
    ]);

    // Camera follows the player across large maps.
    game.camera.follow(player);
  }
}
