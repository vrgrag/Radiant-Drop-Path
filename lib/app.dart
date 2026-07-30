import 'package:flutter/material.dart';
import 'relay/beam_router.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';
import 'screens/loading/loading_screen.dart';
import 'screens/home/main_menu_screen.dart';
import 'screens/levels/level_select_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/endless/endless_screen.dart';
import 'screens/lab/lab_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/webview/simple_webview_screen.dart';
import 'screens/guide/guide_screen.dart';

class Routes {
  Routes._();
  static const loading = '/';
  static const mainMenu = '/menu';
  static const levelSelect = '/levels';
  static const game = '/game';
  static const endless = '/endless';
  static const lab = '/lab';
  static const settings = '/settings';
  static const webview = '/webview';
  static const guide = '/guide';
}

class RadiantDropPathApp extends StatefulWidget {
  const RadiantDropPathApp({super.key, this.router});

  final BeamRouter? router;

  @override
  State<RadiantDropPathApp> createState() => _RadiantDropPathAppState();
}

class _RadiantDropPathAppState extends State<RadiantDropPathApp> with WidgetsBindingObserver {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        AudioService.instance.pauseForBackground();
        break;
      case AppLifecycleState.resumed:
        AudioService.instance.resumeFromBackground();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radiant Drop Path',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: Routes.loading,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case Routes.loading:
            return MaterialPageRoute(
              builder: (_) => LoadingScreen(router: widget.router),
            );
          case Routes.mainMenu:
            return MaterialPageRoute(builder: (_) => const MainMenuScreen());
          case Routes.levelSelect:
            return MaterialPageRoute(builder: (_) => const LevelSelectScreen());
          case Routes.game:
            final levelId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => GameScreen(levelId: levelId));
          case Routes.endless:
            return MaterialPageRoute(builder: (_) => const EndlessScreen());
          case Routes.lab:
            return MaterialPageRoute(builder: (_) => const LabScreen());
          case Routes.settings:
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case Routes.webview:
            final args = settings.arguments as WebViewArgs;
            return MaterialPageRoute(builder: (_) => SimpleWebViewScreen(args: args));
          case Routes.guide:
            final initialTab = settings.arguments is int ? settings.arguments as int : 0;
            return MaterialPageRoute(builder: (_) => GuideScreen(initialTab: initialTab));
          default:
            return MaterialPageRoute(
              builder: (_) => LoadingScreen(router: widget.router),
            );
        }
      },
    );
  }
}
