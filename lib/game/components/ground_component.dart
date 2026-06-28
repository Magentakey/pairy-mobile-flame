import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// Hitbox solid untuk tile tanah/platform dari Tiled.
/// Tidak ada render — visual sudah ditangani oleh TiledComponent.
class GroundComponent extends PositionComponent with CollisionCallbacks {
  GroundComponent({required super.position, required super.size});

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }
}
