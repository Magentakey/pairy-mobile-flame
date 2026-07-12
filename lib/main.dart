import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();
  await AudioService.init();
  runApp(const PairyApp());
}