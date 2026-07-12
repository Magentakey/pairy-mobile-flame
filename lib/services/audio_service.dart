import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service terpusat untuk SFX dan BGM.
/// SFX pakai AudioPool (preload + reuse instance) supaya ringan saat
/// dipanggil berkali-kali cepat (lever/button di-spam, dll).
/// menuBgm dipakai di Home & MapSelect (tidak restart saat pindah antar
/// keduanya). gameBgm selalu restart tiap masuk Gameplay.
class AudioService {
  AudioService._();

  static const String menuBgm = 'bgm/ThePathOfGoblinKing.ogg';
  static const String gameBgm = 'bgm/PlatformShoes8Instumental.ogg';

  static const String _sfxJump = 'sfx/sfx_jump.ogg';
  static const String _sfxBump = 'sfx/sfx_bump.ogg';
  static const String _sfxDisappear = 'sfx/sfx_disappear.ogg';
  static const String _sfxButton = 'sfx/switch_003.ogg';
  static const String _sfxLever = 'sfx/toggle_001.ogg';
  static const String _sfxLevelComplete = 'sfx/level_complete.ogg';
  static const String _sfxFountainTouch = 'sfx/fountain-touch.ogg';

  static bool _initialized = false;
  static bool _menuBgmPlaying = false;

  static const String _prefsSfxVolumeKey = 'audio_sfx_volume';
  static const String _prefsBgmVolumeKey = 'audio_bgm_volume';

  /// Volume global (0.0-1.0), terpisah untuk SFX & BGM, di-persist ke prefs.
  /// _bgmVolume (slider) HANYA berlaku untuk gameBgm — menuBgm sengaja
  /// tidak ikut slider, selalu diputar di volume tetapnya sendiri.
  static double _sfxVolume = 1.0;
  static double _bgmVolume = 1.0;

  /// Basis volume tetap untuk menuBgm, TIDAK dikalikan _bgmVolume.
  /// File ThePathOfGoblinKing.ogg sudah di-loudness-normalize (~-15 LUFS,
  /// sepadan dengan gameBgm) lewat ffmpeg loudnorm, jadi cukup 1.0 di sini
  /// — TIDAK perlu diisi angka >1.0, karena native audio player akan
  /// meng-clamp berapa pun nilai di atas 1.0 jadi 1.0 (tidak ada efek
  /// tambahan, hanya percuma).
  static const double _menuBgmBaseVolume = 1.0;

  /// Basis volume gameBgm, dikalikan _bgmVolume (slider) setiap saat.
  /// Disamakan dengan _menuBgmBaseVolume (1.0) supaya BGM gameplay dan
  /// menu terdengar sebanding di volume slider maksimal.
  static const double _gameBgmBaseVolume = 1.0;

  /// Track mana yang sedang aktif, dipakai [setBgmVolume] untuk
  /// menentukan apakah live-update volume perlu diterapkan (hanya
  /// kalau gameBgm yang sedang main).
  static bool _gameBgmActive = false;

  static double get sfxVolume => _sfxVolume;
  static double get bgmVolume => _bgmVolume;

  // ══════════════════════════════════════════════════════════════════
  // ── KONFIGURASI MANUAL (edit di sini) ───────────────────────────────
  // Nilai volume yang dipakai saat toggle BGM/SFX di posisi ON.
  // Ubah angka di bawah sesuai selera (rentang 0.0 - 1.0), tidak perlu
  // ubah kode di tempat lain.
  static const double bgmOnVolume = 1.0;
  static const double sfxOnVolume = 1.0;
  // ══════════════════════════════════════════════════════════════════

  static final Map<String, AudioPool> _pools = {};

  /// Preload semua audio + siapkan AudioPool tiap SFX. Aman dipanggil ulang.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _sfxVolume = prefs.getDouble(_prefsSfxVolumeKey) ?? 1.0;
      _bgmVolume = prefs.getDouble(_prefsBgmVolumeKey) ?? 1.0;
    } catch (_) {
      // fallback ke default 1.0
    }

    try {
      await FlameAudio.audioCache.loadAll([
        _sfxJump,
        _sfxBump,
        _sfxDisappear,
        _sfxButton,
        _sfxLever,
        _sfxLevelComplete,
        _sfxFountainTouch,
        menuBgm,
        gameBgm,
      ]);

      Future<void> makePool(String file, {int maxPlayers = 3}) async {
        _pools[file] = await FlameAudio.createPool(
          file,
          maxPlayers: maxPlayers,
        );
      }

      await Future.wait([
        makePool(_sfxJump),
        makePool(_sfxBump),
        makePool(_sfxDisappear),
        makePool(_sfxButton),
        makePool(_sfxLever, maxPlayers: 4),
        makePool(_sfxLevelComplete, maxPlayers: 1),
        makePool(_sfxFountainTouch),
      ]);
    } catch (_) {
      // jangan crash game kalau preload gagal
    }
  }

  // ── BGM ──────────────────────────────────────────────────────────

  /// Play/lanjutkan BGM menu (Home & MapSelect), tidak restart kalau sudah main.
  /// Volume tetap ([_menuBgmBaseVolume]), tidak terpengaruh slider BGM.
  static Future<void> playMenuBgm() async {
    _gameBgmActive = false;
    if (_menuBgmPlaying) return;
    _menuBgmPlaying = true;
    try {
      await FlameAudio.bgm.play(menuBgm, volume: _menuBgmBaseVolume);
    } catch (_) {}
  }

  /// Play BGM gameplay, selalu restart dari awal. Volume ikut slider BGM.
  static Future<void> playGameBgm() async {
    _menuBgmPlaying = false;
    _gameBgmActive = true;
    try {
      await FlameAudio.bgm.play(
        gameBgm,
        volume: _gameBgmBaseVolume * _bgmVolume,
      );
    } catch (_) {}
  }

  static Future<void> stopBgm() async {
    _menuBgmPlaying = false;
    _gameBgmActive = false;
    _pausedByLifecycle = false;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  /// True kalau BGM (menu ATAU game) sedang di-pause oleh [pauseBgm],
  /// dipakai [resumeBgm] supaya tidak asal resume kalau memang belum
  /// pernah diputar/sudah di-stop lewat jalur lain.
  static bool _pausedByLifecycle = false;

  /// Pause BGM yang sedang aktif (menu atau game), dipanggil saat app
  /// masuk background (AppLifecycleState.paused/hidden). Track mana pun
  /// yang sedang main (menuBgm/gameBgm) sama-sama ke-pause, karena
  /// keduanya berbagi satu channel FlameAudio.bgm.
  static Future<void> pauseBgm() async {
    if (!_menuBgmPlaying && !_gameBgmActive) return;
    try {
      await FlameAudio.bgm.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// Lanjutkan BGM yang tadi di-pause [pauseBgm], dipanggil saat app
  /// kembali ke foreground (AppLifecycleState.resumed). Tidak melakukan
  /// apa-apa kalau sebelumnya tidak di-pause oleh lifecycle (mis. BGM
  /// memang belum pernah main atau sudah di-stop lewat jalur lain).
  static Future<void> resumeBgm() async {
    if (!_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await FlameAudio.bgm.resume();
    } catch (_) {}
  }

  /// Ganti volume BGM (0.0-1.0), persist selalu. Live-apply hanya kalau
  /// gameBgm yang sedang main — menuBgm tidak terpengaruh slider ini.
  static Future<void> setBgmVolume(double volume) async {
    _bgmVolume = volume.clamp(0.0, 1.0);
    if (_gameBgmActive) {
      try {
        await FlameAudio.bgm.audioPlayer.setVolume(
          _gameBgmBaseVolume * _bgmVolume,
        );
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsBgmVolumeKey, _bgmVolume);
    } catch (_) {}
  }

  /// Ganti volume SFX (0.0-1.0), berlaku untuk pemanggilan berikutnya.
  static Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsSfxVolumeKey, _sfxVolume);
    } catch (_) {}
  }

  // ── SFX ──────────────────────────────────────────────────────────

  static void playJump() => _playSfx(_sfxJump, volume: 0.7);
  static void playBump() => _playSfx(_sfxBump, volume: 1.0);
  static void playDisappear() => _playSfx(_sfxDisappear, volume: 0.8);
  static void playButton() => _playSfx(_sfxButton, volume: 0.4);
  static void playLever() => _playSfx(_sfxLever, volume: 0.15);
  static void playLevelComplete() => _playSfx(_sfxLevelComplete, volume: 0.9);
  static void playFountainTouch() => _playSfx(_sfxFountainTouch, volume: 0.7);

  static void _playSfx(String file, {double volume = 0.7}) {
    final effectiveVolume = (volume * _sfxVolume).clamp(0.0, 1.0);
    final pool = _pools[file];
    if (pool == null) {
      // fallback kalau pool belum siap
      // ignore: discarded_futures
      FlameAudio.play(file, volume: effectiveVolume).catchError((_) {});
      return;
    }
    // ignore: discarded_futures
    pool.start(volume: effectiveVolume).catchError((_) => '');
  }
}
