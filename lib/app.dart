import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/map_select_screen.dart';
import 'screens/gameplay_screen.dart';

class PairyApp extends StatelessWidget {
  const PairyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/':           (_) => const HomeScreen(),
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
