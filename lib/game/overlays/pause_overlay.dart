import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../pairy_game.dart';
import 'overlay_button.dart';

class PauseOverlay extends StatefulWidget {
  const PauseOverlay({super.key, required this.game});
  final PairyGame game;

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay> {
  late double _sfxVolume = AudioService.sfxVolume;
  late double _bgmVolume = AudioService.bgmVolume;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Paused',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _VolumeSlider(
                    icon: Icons.music_note_rounded,
                    label: 'BGM',
                    value: _bgmVolume,
                    onChanged: (v) {
                      setState(() => _bgmVolume = v);
                      // ignore: discarded_futures
                      AudioService.setBgmVolume(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  _VolumeSlider(
                    icon: Icons.graphic_eq_rounded,
                    label: 'SFX',
                    value: _sfxVolume,
                    onChanged: (v) {
                      setState(() => _sfxVolume = v);
                      // ignore: discarded_futures
                      AudioService.setSfxVolume(v);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OverlayButton(
                          label: 'Resume',
                          icon: Icons.play_arrow_rounded,
                          color: const Color(0xFF34C77B),
                          onTap: widget.game.resumeFromPause,
                          fullWidth: true,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OverlayButton(
                          label: 'Restart',
                          icon: Icons.replay_rounded,
                          color: const Color(0xFFE85C4A),
                          onTap: widget.game.restartLevel,
                          fullWidth: true,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OverlayButton(
                    label: 'Back to Map',
                    icon: Icons.map_outlined,
                    color: const Color(0xFF333355),
                    onTap: widget.game.backToMap,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Baris slider volume tunggal (dipakai buat BGM & SFX), gaya konsisten
/// sama tema gelap pause overlay lainnya.
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF34C77B),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${(value * 100).round()}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
