import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../game/pairy_game.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';

class MapSelectScreen extends StatefulWidget {
  const MapSelectScreen({super.key});

  @override
  State<MapSelectScreen> createState() => _MapSelectScreenState();
}

class _MapSelectScreenState extends State<MapSelectScreen> {
  static const int cols = 4;
  static const int rows = 3;
  static const int displaySlots = cols * rows; // 12

  // Warna khusus untuk level yang sedang aktif tapi belum di-clear.
  // Didefinisikan lokal di sini supaya tidak perlu ubah app_colors.dart.
  static const Color _currentLevelColor = Color(0xFFF2B94D);

  int _unlockedCount = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    // init() sudah dipanggil sekali di main.dart, jadi di sini cukup
    // play saja (guarded, tidak restart kalau sudah jalan dari Home).
    AudioService.playMenuBgm();
  }

  Future<void> _loadProgress() async {
    final unlocked = await ProgressService.getUnlockedLevel();
    if (mounted)
      setState(() {
        _unlockedCount = unlocked;
        _loading = false;
      });
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Delete Progress',
          style: TextStyle(
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        content: const Text(
          'All progress will be lost. Only Level 1 will be available.',
          style: TextStyle(
            color: Colors.white70,
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE85C4A)),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ProgressService.deleteProgress();
      _loadProgress();
    }
  }

  /// Menentukan warna level nomor [n].
  /// - n < _unlockedCount  → sudah di-clear (hijau)
  /// - n == _unlockedCount → level aktif, belum di-clear (kuning/oranye)
  /// - n > _unlockedCount  → masih terkunci (abu-abu)
  Color _colorFor(int n) {
    final total = PairyGame.levelNames.length - 1; // -1: exclude tutorial
    if (n > total)
      return AppColors.levelLocked; // map belum dibuat, selalu locked
    if (n < _unlockedCount) return AppColors.primaryGreen;
    if (n == _unlockedCount) return _currentLevelColor;
    return AppColors.levelLocked;
  }

  bool _isPlayable(int n) {
    final total = PairyGame.levelNames.length - 1; // -1: exclude tutorial
    return n <= _unlockedCount && n <= total;
  }

  @override
  Widget build(BuildContext context) {
    final total = PairyGame.levelNames.length - 1; // -1: exclude tutorial
    final slots = displaySlots > total ? displaySlots : total;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Center(
                child: Text(
                  'Select Level',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),

            // ── Legend ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: AppColors.primaryGreen, label: 'Cleared'),
                  const SizedBox(width: 16),
                  const _LegendDot(color: _currentLevelColor, label: 'Current'),
                  const SizedBox(width: 16),
                  _LegendDot(color: AppColors.levelLocked, label: 'Locked'),
                ],
              ),
            ),

            // ── Tutorial: "first map", selalu playable, tidak ikut
            // penomoran grid ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      '/gameplay',
                      arguments: 0, // levelNames[0] = 'tutorial'
                    );
                    _loadProgress();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Tutorial',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Level grid: manual Column+Row, dijamin pas 4 kolom x 3 baris tanpa scroll ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 8,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 12.0;

                          // Circle size dari sisi yang lebih membatasi,
                          // dipakai untuk kedua dimensi biar proporsional.
                          final cellW =
                              (constraints.maxWidth - spacing * (cols - 1)) /
                              cols;
                          final cellH =
                              (constraints.maxHeight - spacing * (rows - 1)) /
                              rows;
                          final cellSize = cellW < cellH ? cellW : cellH;
                          final circleSize = cellSize.clamp(0.0, 64.0);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(rows, (r) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: r == rows - 1 ? 0 : spacing,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(cols, (c) {
                                    final i = r * cols + c;
                                    if (i >= slots) {
                                      return SizedBox(width: cellW);
                                    }
                                    final n = i + 1;
                                    final ok = _isPlayable(n);
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: c == cols - 1 ? 0 : spacing,
                                      ),
                                      child: SizedBox(
                                        width: cellW,
                                        child: Center(
                                          child: GestureDetector(
                                            onTap: ok
                                                ? () async {
                                                    await Navigator.pushNamed(
                                                      context,
                                                      '/gameplay',
                                                      arguments: n,
                                                    );
                                                    // Reload progress setelah kembali dari gameplay
                                                    _loadProgress();
                                                  }
                                                : null,
                                            child: Container(
                                              width: circleSize,
                                              height: circleSize,
                                              decoration: BoxDecoration(
                                                color: _colorFor(n),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: ok
                                                    ? Text(
                                                        '$n',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize:
                                                              circleSize * 0.32,
                                                          decoration:
                                                              TextDecoration
                                                                  .none,
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons.lock,
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                        size: circleSize * 0.36,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
            ),

            // ── Back & Delete Save ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '< Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _confirmDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE85C4A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Delete Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget kecil untuk legend warna di bawah judul.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
