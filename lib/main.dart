import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'game/pairy_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();

  final game = PairyGame();
  runApp(
    GameWidget(
      game: kDebugMode ? PairyGame() : game,
    ),
  );
}
