import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Komponen text untuk ditaruh di map lewat Tiled (object class_ "Text").
/// Isi teks dari custom property "content" (bukan `name`, karena `name`
/// dipakai untuk pairing ke trigger zone, lihat [TriggerZoneComponent]).
/// Murni visual, tanpa hitbox/collision.
///
/// Default sembunyi total. Kalau di-pair dengan trigger zone, muncul
/// lewat animasi wipe kiri-ke-kanan saat trigger aktif (lihat
/// [reveal]/[hide]). Tanpa pasangan trigger, langsung tampil penuh
/// (label statis).
///
/// Priority rendah supaya tergambar di atas background/ground tapi di
/// bawah komponen interaktif lain.
class MapTextComponent extends PositionComponent {
  MapTextComponent({
    required this.text,
    required super.position,
    this.fontSize = 12,
    super.anchor = Anchor.center,
  });

  final String text;
  final double fontSize;

  static const double _revealDuration = 0.7;
  static const double _fadeWidth = 16;
  static const double _particleSpawnInterval = 0.03;

  late TextPainter _fillPainter;
  late TextPainter _strokePainter;

  // Buffer di sekeliling text supaya ink stroke (yang melebar keluar
  // dari batas ukuran fill/layout normal — mis. bawah huruf "g"/"y" atau
  // ujung kanan huruf terakhir) TIDAK ke-clip sama saveLayer/mask.
  late double _pad;

  // 0 = tidak kelihatan sama sekali, 1 = full reveal.
  double _progress = 0;
  double _target = 0;
  double _particleSpawnTimer = 0;
  final List<_WipeParticle> _particles = [];
  final Random _rng = Random();

  @override
  Future<void> onLoad() async {
    _strokePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize / 4
            ..color = Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    _fillPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    size = Vector2(_fillPainter.size.width, _fillPainter.size.height);
    _pad = fontSize / 4 + 2;
  }

  /// Mulai animasi memunculkan teks dari kiri ke kanan (dipanggil dari
  /// _TriggerGroup.recompute saat trigger yang di-pair aktif).
  void reveal() => _target = 1;

  /// Mulai animasi menyembunyikan teks lagi (kebalikan dari [reveal]).
  void hide() => _target = 0;

  /// Langsung tampil penuh TANPA animasi — dipakai untuk text yang tidak
  /// punya pasangan trigger sama sekali (name kosong / berdiri sendiri).
  void showInstantly() {
    _progress = 1;
    _target = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_progress != _target) {
      final dir = _target > _progress ? 1 : -1;
      _progress = (_progress + dir * dt / _revealDuration).clamp(0.0, 1.0);
      if ((dir > 0 && _progress >= _target) ||
          (dir < 0 && _progress <= _target)) {
        _progress = _target;
      }
    }

    final isAnimating =
        _progress != _target || (_progress > 0 && _progress < 1);

    if (isAnimating && size.x > 0) {
      _particleSpawnTimer += dt;
      final totalTravel = size.x + _fadeWidth * 2;
      final edgeX = (-_fadeWidth + _progress * totalTravel).clamp(0.0, size.x);
      while (_particleSpawnTimer >= _particleSpawnInterval) {
        _particleSpawnTimer -= _particleSpawnInterval;
        _particles.add(
          _WipeParticle(
            position: Vector2(
              edgeX + _rng.nextDouble() * 4 - 2,
              _rng.nextDouble() * size.y,
            ),
            velocity: Vector2(
              (_rng.nextDouble() - 0.2) * 18,
              (_rng.nextDouble() - 0.5) * 14,
            ),
            life: 0.35 + _rng.nextDouble() * 0.15,
          ),
        );
      }
    }

    for (final p in _particles) {
      p.age += dt;
      p.position.add(p.velocity * dt);
    }
    _particles.removeWhere((p) => p.age >= p.life);
  }

  @override
  void render(Canvas canvas) {
    if (_progress <= 0 && _particles.isEmpty) return;

    if (_progress > 0 && size.x > 0) {
      // Layer digambar LEBIH LEBAR dari ukuran text (dibuffer [_pad] di
      // semua sisi) supaya ink stroke yang melebar keluar dari layout
      // box normal (mis. ekor huruf "g" di bawah, atau ujung kanan
      // huruf terakhir) tidak ke-clip oleh saveLayer/mask — sebelumnya
      // itu yang bikin muncul garis tipis di tepi.
      final layerRect = Rect.fromLTWH(
        -_pad,
        -_pad,
        size.x + _pad * 2,
        size.y + _pad * 2,
      );
      canvas.saveLayer(layerRect, Paint());

      _strokePainter.paint(canvas, Offset.zero);
      _fillPainter.paint(canvas, Offset.zero);

      // Titik wipe SENGAJA dibuat melewati batas kiri & kanan text
      // (bukan berhenti pas di ujung), supaya pas full progress teksnya
      // utuh 100% opaque (transparan cuma "lewat" sekilas), bukan
      // nyisain fade permanen di ujung.
      final totalTravel = size.x + _fadeWidth * 2;
      final revealX = -_fadeWidth + _progress * totalTravel;
      final fadeStart = revealX - _fadeWidth;

      // Pakai ui.Gradient.linear dengan koordinat piksel absolut
      // (bukan rect-relative/Alignment) supaya posisi wipe selalu pas
      // sesuai lebar text asli, tidak terpengaruh oleh layerRect yang
      // sengaja diperlebar buat buffer stroke di atas.
      final shader = ui.Gradient.linear(
        Offset(fadeStart, 0),
        Offset(revealX, 0),
        const [Colors.white, Color(0x00FFFFFF)],
      );
      final maskPaint = Paint()
        ..shader = shader
        ..blendMode = BlendMode.dstIn;
      canvas.drawRect(layerRect, maskPaint);

      canvas.restore();
    }

    // Particle wipe digambar di atas, TIDAK ikut mask, supaya tetap
    // kelihatan walau numpuk persis di tepi kiri/kanan teks yang lagi
    // di-fade.
    for (final p in _particles) {
      final t = (1 - (p.age / p.life)).clamp(0.0, 1.0);
      final paint = Paint()..color = Colors.white.withValues(alpha: t * 0.9);
      canvas.drawCircle(
        Offset(p.position.x, p.position.y),
        1.6 * t.clamp(0.2, 1.0) + 0.4,
        paint,
      );
    }
  }
}

class _WipeParticle {
  _WipeParticle({
    required this.position,
    required this.velocity,
    required this.life,
  });

  final Vector2 position;
  final Vector2 velocity;
  final double life;
  double age = 0;
}
