/// Centralized route names so screens never hardcode magic strings.
///
/// Gameplay is reached via [onGenerateRoute] in app.dart so a `levelId`
/// (int) can be passed as the route argument:
/// `Navigator.pushNamed(context, AppRoutes.gameplay, arguments: 1);`
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String mapSelect = '/map-select';
  static const String gameplay = '/gameplay';
}
