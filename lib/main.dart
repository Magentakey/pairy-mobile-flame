import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape (PRD §13 — Android landscape only).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide status and navigation bars for a full-screen game feel.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const PairyApp());
}
