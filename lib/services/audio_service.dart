import 'package:flame_audio/flame_audio.dart';

/// Service terpusat untuk SFX dan BGM.
///
/// ── Kenapa pakai AudioPool untuk SFX ────────────────────────────────
/// `FlameAudio.play(file)` (dipakai di versi awal) bikin instance
/// `MediaPlayer` NATIVE baru setiap kali dipanggil. Di Android itu berat
/// (alokasi/dekode/rilis native tiap panggilan) — begitu lever/button
/// dipencet berkali-kali cepat, main thread ke-block sampai ratusan
/// frame ke-skip (lihat log `Choreographer: Skipped ... frames`), yang
/// bikin SFX kedengeran delay, dan SFX lain yang jatuh pas thread lagi
/// macet (mis. fountain-touch pas fairy nyentuh sebentar) jadi ke-drop
/// sama sekali karena Future-nya nggak sempat selesai/keburu di-skip.
///
/// [AudioPool] preload beberapa instance player untuk 1 file dan
/// tinggal "dipinjam" (start) saat dipanggil — jauh lebih ringan/instant,
/// cocok buat SFX pendek yang bisa overlapping (lever di-spam, dsb).
///
/// ── BGM ────────────────────────────────────────────────────────────
/// - [menuBgm] ("ThePathOfGoblinKing.ogg"): dipakai selama di Home &
///   MapSelect. Selama berpindah-pindah ANTARA Home <-> MapSelect,
///   bgm ini TIDAK di-restart — tetap lanjut dari posisi sebelumnya
///   (lihat guard [_menuBgmPlaying] di [playMenuBgm]).
/// - [gameBgm] ("PlatformShoes8Instumental.ogg"): dipakai selama di
///   Gameplay (tutorial maupun level manapun). SELALU restart dari
///   awal setiap kali masuk ke Gameplay (dipanggil tiap [playGameBgm]).
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

  static final Map<String, AudioPool> _pools = {};

  /// Preload semua file audio + siapkan AudioPool untuk tiap SFX.
  /// Aman dipanggil berkali-kali (no-op setelah pertama kali berhasil).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
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

      // maxPlayers 3-4: cukup buat overlap wajar (mis. lever dipencet
      // 2x beruntun sebelum instance pertama selesai) tanpa boros memori.
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
        makePool(_sfxLever, maxPlayers: 4), // sering di-spam
        makePool(_sfxLevelComplete, maxPlayers: 1),
        makePool(_sfxFountainTouch),
      ]);
    } catch (_) {
      // Kalau preload/pool gagal (mis. device audio bermasalah), jangan
      // crash seluruh game — _playSfx di bawah sudah null-safe kalau
      // pool belum sempat kebentuk.
    }
  }

  // ── BGM ────────────────────────────────────────────────────────────

  /// Play/lanjutkan BGM menu (Home & MapSelect). Kalau BGM ini sudah
  /// berjalan (berpindah antar Home <-> MapSelect), TIDAK di-restart.
  static Future<void> playMenuBgm() async {
    if (_menuBgmPlaying) return;
    _menuBgmPlaying = true;
    try {
      await FlameAudio.bgm.play(menuBgm, volume: 1.3);
    } catch (_) {}
  }

  /// Play BGM gameplay, SELALU restart dari awal.
  static Future<void> playGameBgm() async {
    _menuBgmPlaying = false;
    try {
      await FlameAudio.bgm.play(gameBgm, volume: 0.3);
    } catch (_) {}
  }

  static Future<void> stopBgm() async {
    _menuBgmPlaying = false;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  // ── SFX ──────────────────────────────────────────────────────────
  // Volume per-SFX disesuaikan manual (toggle_001/lever sebelumnya
  // kekencengan dibanding yang lain, jadi diturunkan relatif).

  static void playJump() => _playSfx(_sfxJump, volume: 0.4);
  static void playBump() => _playSfx(_sfxBump, volume: 1.0);
  static void playDisappear() => _playSfx(_sfxDisappear, volume: 0.8);
  static void playButton() => _playSfx(_sfxButton, volume: 0.4);
  static void playLever() => _playSfx(_sfxLever, volume: 0.15);
  static void playLevelComplete() => _playSfx(_sfxLevelComplete, volume: 0.9);
  static void playFountainTouch() =>
      _playSfx(_sfxFountainTouch, volume: 0.7);

  static void _playSfx(String file, {double volume = 0.7}) {
    final pool = _pools[file];
    if (pool == null) {
      // Pool belum siap (mis. init() belum selesai) — fallback ke
      // FlameAudio.play biasa daripada diam saja tanpa suara sama sekali.
      // ignore: discarded_futures
      FlameAudio.play(file, volume: volume).catchError((_) {});
      return;
    }
    // ignore: discarded_futures
    pool.start(volume: volume).catchError((_) => '');
  }
}