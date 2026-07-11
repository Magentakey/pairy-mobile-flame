import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'player_component.dart';
import 'stone_brick_component.dart';

/// Mode operasi [ButtonComponent] — dipilih lewat custom property `mode`
/// di Tiled (string: 'plate' | 'toggle' | 'timer'), default 'plate'.
enum ButtonMode { plate, toggle, timer }

/// Tombol yang ter-trigger kalau [PlayerComponent] ATAU [StoneBrickComponent]
/// berada di atasnya. Anchor.bottomCenter — titik spawn di Tiled = alas
/// button, konsisten dengan Lever/Fountain/Gate.
///
/// Overlap dideteksi MANUAL (AABB rect-rect) tiap frame, bukan lewat
/// Flame CollisionCallbacks — konsisten dengan pola FountainComponent,
/// supaya bisa cek 2 tipe object sekaligus (Player & StoneBrick) dengan
/// logika yang sama tanpa bergantung urutan event collision start/end
/// dari 2 sumber berbeda. RectangleHitbox tetap ditambahkan (passive)
/// murni untuk outline debug mode, sama seperti Lever.
///
/// 3 mode:
/// - [ButtonMode.plate]: ON selama masih diinjak, OFF begitu dilepas —
///   persis seperti FountainComponent.
/// - [ButtonMode.toggle]: tiap kali mulai diinjak (rising edge, dari
///   kosong ke terisi), state di-flip dan MENETAP — nggak peduli lama
///   diinjak atau lepas lagi, sampai diinjak ulang buat flip balik.
/// - [ButtonMode.timer]: begitu diinjak pertama kali, ON dan mulai
///   countdown dari [timerDuration] detik. Countdown CUMA berjalan
///   selama masih ada yang menginjak — begitu dilepas, countdown
///   nge-pause di sisa waktu yang ada (bukan reset, bukan lanjut jalan
///   sendiri). Begitu countdown habis, OFF (dan reset lagi buat siklus
///   berikutnya). Sisa waktu ditampilkan sebagai tooltip kecil di atas
///   button selama ON.
///
/// Pairing (`name` di Tiled) dan custom property `actived` (ekspektasi
/// AND grup trigger) bekerja identik dengan Lever/Fountain — lewat
/// [onActivationChanged] yang dipanggil setiap [isOn] berubah, dikonsumsi
/// oleh _TriggerGroup di level.dart.
class ButtonComponent extends PositionComponent with CollisionCallbacks {
  ButtonComponent({
    required super.position,
    this.mode = ButtonMode.plate,
    this.timerDuration = 3.0,
    this.onActivationChanged,
  }) : super(size: Vector2(20, 8), anchor: Anchor.bottomCenter);

  final ButtonMode mode;

  /// Durasi countdown (detik), cuma dipakai kalau [mode] == timer.
  final double timerDuration;

  /// Dipanggil setiap [isOn] berubah — dipakai grup trigger buat
  /// recompute AND (sama seperti Lever/Fountain).
  final VoidCallback? onActivationChanged;

  bool isOn = false;

  /// Sisa waktu countdown (mode timer saja). Dipertahankan/di-pause
  /// selama tidak ada yang menginjak, TIDAK direset sampai habis.
  double _remaining = 0;
  bool _wasPressed = false;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
    _remaining = timerDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (parent == null) return;

    final pressed = _isPressed();

    if (mode == ButtonMode.plate) {
      if (pressed != isOn) {
        isOn = pressed;
        onActivationChanged?.call();
      }
    } else if (mode == ButtonMode.toggle) {
      if (pressed && !_wasPressed) {
        isOn = !isOn;
        onActivationChanged?.call();
      }
    } else {
      // ButtonMode.timer
      if (pressed && !_wasPressed && !isOn) {
        isOn = true;
        onActivationChanged?.call();
      }
      if (isOn && !pressed) {
        // Countdown JALAN cuma selama TIDAK diinjak (dilepas). Selama
        // masih diinjak, countdown PAUSE di sisa waktu yang ada.
        _remaining -= dt;
        if (_remaining <= 0) {
          _remaining = timerDuration;
          isOn = false;
          onActivationChanged?.call();
        }
      }
      // Kalau isOn && pressed: _remaining SENGAJA tidak diubah (pause).
    }

    _wasPressed = pressed;
  }

  bool _isPressed() {
    for (final child in parent!.children) {
      if (child is PlayerComponent && _overlaps(child)) return true;
      if (child is StoneBrickComponent && _overlaps(child)) return true;
    }
    return false;
  }

  bool _overlaps(PositionComponent other) {
    final myTl = position - Vector2(size.x * anchor.x, size.y * anchor.y);
    final otherTl =
        other.position -
        Vector2(other.size.x * other.anchor.x, other.size.y * other.anchor.y);
    return myTl.x < otherTl.x + other.size.x &&
        myTl.x + size.x > otherTl.x &&
        myTl.y < otherTl.y + other.size.y &&
        myTl.y + size.y > otherTl.y;
  }

  @override
  void render(Canvas canvas) {
    // Local (0,0) = top-left bounding box (konvensi standar Flame).
    const baseColor = Color(0xFF555577);
    final topColor = isOn ? const Color(0xFF34C77B) : const Color(0xFFE85C4A);

    // Dudukan/alas — tetap di tempat.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.y * 0.5, size.x, size.y * 0.5),
        const Radius.circular(2),
      ),
      Paint()..color = baseColor,
    );

    // Permukaan tombol "turun" dikit kalau lagi ON (efek ketekan).
    final pressedOffset = isOn ? 2.0 : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, pressedOffset, size.x - 2, size.y * 0.6),
        const Radius.circular(2),
      ),
      Paint()..color = topColor,
    );

    // Tooltip countdown — cuma mode timer, cuma selama ON.
    if (mode == ButtonMode.timer && isOn) {
      final label = _remaining.ceil().toString();
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final bgRect = Rect.fromCenter(
        center: Offset(size.x / 2, -8),
        width: painter.width + 8,
        height: painter.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        Paint()..color = const Color(0xCC222233),
      );
      painter.paint(
        canvas,
        Offset(
          bgRect.left + (bgRect.width - painter.width) / 2,
          bgRect.top + (bgRect.height - painter.height) / 2,
        ),
      );
    }
  }
}
