import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk menyimpan dan membaca progress level secara lokal.
///
/// Data yang disimpan:
///   - `pairy_unlocked` (int): jumlah level yang sudah di-unlock.
///     Nilai 1 = hanya Level 1 yang bisa dimainkan (default).
///
/// Semua metode static, tidak perlu instansiasi.
class ProgressService {
  ProgressService._();

  static const String _keyUnlocked = 'pairy_unlocked';

  /// Jumlah level unlocked (1-based: 1 = hanya level 1, 2 = level 1 & 2, dst).
  static Future<int> getUnlockedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUnlocked) ?? 1;
  }

  /// Dipanggil saat level selesai.
  /// [levelNumber] = nomor level yang baru saja di-unlock (1-based).
  /// Hanya menulis jika levelNumber lebih tinggi dari yang tersimpan.
  static Future<void> unlockLevel(int levelNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyUnlocked) ?? 1;
    if (levelNumber > current) {
      await prefs.setInt(_keyUnlocked, levelNumber);
    }
  }

  /// Hapus semua progress — kembali ke default (hanya Level 1 unlocked).
  static Future<void> deleteProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUnlocked);
  }
}
