import 'package:flutter/material.dart';

class OverlayButton extends StatelessWidget {
  const OverlayButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;
  // Dipakai saat tombol ditaruh berdampingan (mis. dalam Row/Expanded)
  // dan ruangnya terbatas — padding & spacing dikecilkan supaya teks
  // tidak overflow.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 24,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: compact ? 6 : 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
