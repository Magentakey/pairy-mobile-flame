import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/routes.dart';
import '../models/level_info.dart';
import '../widgets/pairy_button.dart';

/// Map / level-select screen (PRD 7.2).
///
/// Wireframe shows a header "select map" and a grid of numbered circles.
/// Tapping an unlocked level navigates to [GameplayScreen] passing the
/// level id as a route argument.
///
/// [_unlockedUpTo] is a hard-coded constant for the MVP; swap for a value
/// read from SharedPreferences once save-progress (PRD 6.9) is wired in.
class MapSelectScreen extends StatelessWidget {
  const MapSelectScreen({super.key});

  /// Total level slots shown in the grid (pad to a round number).
  static const int _totalSlots = 16;

  /// How many levels are unlocked in this prototype (Level 1 only).
  static const int _unlockedUpTo = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Select Map',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
            ),

            // ── Level grid ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _totalSlots,
                  itemBuilder: (context, index) {
                    final levelNumber = index + 1;
                    final isUnlocked = levelNumber <= _unlockedUpTo;
                    return _LevelSlot(
                      number: levelNumber,
                      isUnlocked: isUnlocked,
                      onTap: isUnlocked
                          ? () => Navigator.pushNamed(
                                context,
                                AppRoutes.gameplay,
                                arguments: levelNumber,
                              )
                          : null,
                    );
                  },
                ),
              ),
            ),

            // ── Back button ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: PairyButton(
                  label: '< Back',
                  color: AppColors.primaryGreen,
                  width: 120,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelSlot extends StatelessWidget {
  const _LevelSlot({
    required this.number,
    required this.isUnlocked,
    this.onTap,
  });

  final int number;
  final bool isUnlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked ? AppColors.primaryGreen : AppColors.levelLocked,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isUnlocked
              ? Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : const Icon(Icons.lock, color: Colors.white54, size: 16),
        ),
      ),
    );
  }
}
