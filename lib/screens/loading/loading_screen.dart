import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app.dart';
import '../../relay/beam_router.dart';
import '../../relay/core/relay_models.dart';
import '../../relay/pages/prism_portal.dart';
import '../../relay/pages/pulse_invite.dart';
import '../../relay/pages/signal_lost_page.dart';
import '../../services/save_service.dart';
import '../../services/audio_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/asset_paths.dart';
import '../../widgets/horizontal_progress_bar.dart';
import '../../widgets/loading_dots_text.dart';

/// First screen shown on cold start. Free to rotate (shows the matching
/// vertical/horizontal art), performs one-time service bootstrap, and
/// locks the rest of the app to portrait right before handing off to the
/// main menu.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, this.router});

  final BeamRouter? router;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  bool _navigated = false;
  RelayStop _stop = const NativeStop();

  @override
  void initState() {
    super.initState();
    // Allow the loading screen itself to rotate freely.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _progress = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..addListener(() => setState(() {}));
    _progress.animateTo(0.92, curve: Curves.easeOutCubic);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();
    await _resolveDestination();
    // Warm the game up only when we are actually going there. Doing it
    // unconditionally would spin up save/audio and decode board artwork for
    // a session that never leaves the portal.
    if (_stop is! PortalStop) {
      await Future.wait([
        SaveService.instance.init(),
        AudioService.instance.init(),
        _precacheArt(),
      ]);
    }
    // Keep the loading experience feeling substantial even on fast
    // devices, then snap the bar to 100% right before we launch.
    const minDisplay = Duration(milliseconds: 1900);
    final remaining = minDisplay - stopwatch.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
    await _finishAndNavigate();
  }

  Future<void> _resolveDestination() async {
    final router = widget.router;
    if (router == null) return;
    try {
      _stop = await router.resolve(onProgress: (_) {});
    } catch (_) {
      _stop = const NativeStop();
    }
  }

  Future<void> _precacheArt() async {
    if (!mounted) return;
    try {
      await Future.wait([
        precacheImage(const AssetImage(AssetPaths.gameLogo), context),
        precacheImage(AssetImage(AssetPaths.chapterBackground(1)), context),
      ]);
    } catch (_) {
      // Non-fatal - the game still works if a background hasn't warmed up.
    }
  }

  Future<void> _finishAndNavigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    await _progress.animateTo(1.0, duration: const Duration(milliseconds: 260), curve: Curves.easeIn);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final router = widget.router;
    final stop = _stop;

    if (router == null || stop is NativeStop) {
      // Lock the rest of the game to portrait only.
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.mainMenu);
      return;
    }

    if (stop is OfflineStop) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SignalLostPage(
            probe: router.probe,
            retryBuilder: (_) => LoadingScreen(router: router),
          ),
        ),
      );
      return;
    }

    if (stop is PortalStop) {
      Widget buildPortal(BuildContext _) => PrismPortal(
        url: stop.url,
        coldLaunch: stop.coldLaunch,
        store: router.store,
        probe: router.probe,
        pulse: router.pulse,
        agent: router.agent,
      );

      final offerInvite =
          router.store.shouldOfferInvite &&
          await router.pulse.canOfferPermission();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: offerInvite
              ? (_) => PulseInvite(
                  store: router.store,
                  pulse: router.pulse,
                  nextBuilder: buildPortal,
                )
              : buildPortal,
        ),
      );
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final bgAsset =
        orientation == Orientation.portrait ? AssetPaths.verticalLoading : AssetPaths.horizontalLoading;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bgAsset, fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HorizontalProgressBar(progress: _progress.value),
                    const SizedBox(height: 14),
                    LoadingDotsText(
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
