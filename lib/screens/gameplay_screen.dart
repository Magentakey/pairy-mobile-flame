import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/routes.dart';
import '../game/overlays/hud_controls_overlay.dart';
import '../game/overlays/pause_overlay.dart';
import '../game/pairy_game.dart';

/// Gameplay screen (PRD 7.3 + 7.4).
///
/// Hosts a [GameWidget] for the Flame canvas and a pure-Flutter [Stack] for:
///   - [HudControlsOverlay] — on-screen movement + jump buttons
///   - Pause icon button (top-right, inside SafeArea)
///   - [PauseOverlay] — shown when [_isPaused] is true
///
/// Receives the level number as a route argument (see [AppRoutes.gameplay]).
/// Currently only one demo level exists, so the argument is stored for
/// future use when Tiled maps are added.
class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, required this.levelNumber});

  final int levelNumber;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late final PairyGame _game;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _game = PairyGame(onLevelComplete: _handleLevelComplete);
  }

  // ── Level complete ───────────────────────────────────────────────────

  void _handleLevelComplete() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Level Selesai! 🎉'),
        content: Text('Kamu menyelesaikan Level ${widget.levelNumber}!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to map select
            },
            child: const Text('Map Select'),
          ),
        ],
      ),
    );
  }

  // ── Pause controls ───────────────────────────────────────────────────

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _game.pauseEngine();
      } else {
        _game.resumeEngine();
      }
    });
  }

  void _retry() {
    setState(() {
      _isPaused = false;
      _game.resumeEngine();
    });
    _game.restartLevel();
  }

  void _exitToMap() {
    _game.resumeEngine();
    Navigator.pop(context);
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Flame canvas ─────────────────────────────────────────
          GameWidget(game: _game),

          // ── HUD controls ─────────────────────────────────────────
          if (!_isPaused) HudControlsOverlay(game: _game),

          // ── Pause button (top-right) ──────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: Colors.black38,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _togglePause,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.pause, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Pause overlay ─────────────────────────────────────────
          if (_isPaused)
            PauseOverlay(
              onResume: _togglePause,
              onRetry: _retry,
              onExit: _exitToMap,
            ),
        ],
      ),
    );
  }
}
