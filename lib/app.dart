import 'package:flutter/material.dart';

import 'core/routes.dart';
import 'screens/gameplay_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_select_screen.dart';

/// Root Flutter widget.
///
/// Uses named routes for simple navigation between Home → Map Select →
/// Gameplay. [AppRoutes.gameplay] uses [onGenerateRoute] so the level
/// number can be passed as a typed argument.
class PairyApp extends StatelessWidget {
  const PairyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pairy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF34C77B)),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.mapSelect: (_) => const MapSelectScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.gameplay) {
          final levelNumber = (settings.arguments as int?) ?? 1;
          return MaterialPageRoute(
            builder: (_) => GameplayScreen(levelNumber: levelNumber),
          );
        }
        return null;
      },
    );
  }
}
