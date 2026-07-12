import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/map_select_screen.dart';
import 'screens/gameplay_screen.dart';
import 'services/audio_service.dart';

class PairyApp extends StatefulWidget {
  const PairyApp({super.key});

  @override
  State<PairyApp> createState() => _PairyAppState();
}

class _PairyAppState extends State<PairyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Pause BGM (menu maupun game, keduanya lewat channel yang sama) saat
  /// app pindah ke background, resume saat kembali ke foreground.
  /// `inactive` sengaja tidak dipause di sini karena state itu juga
  /// muncul sebentar untuk transisi biasa (mis. dialog sistem/permission),
  /// bukan cuma saat benar-benar pindah app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        AudioService.pauseBgm();
      case AppLifecycleState.resumed:
        AudioService.resumeBgm();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/map-select': (_) => const MapSelectScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/gameplay') {
          final levelIndex = (settings.arguments as int?) ?? 0;
          return MaterialPageRoute(
            builder: (_) => GameplayScreen(levelIndex: levelIndex),
          );
        }
        return null;
      },
    );
  }
}
