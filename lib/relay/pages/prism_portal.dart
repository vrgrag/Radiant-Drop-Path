import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../app.dart';
import '../../services/audio_service.dart';
import '../../services/save_service.dart';
import '../config/prism_config.dart';
import '../infra/circuit_store.dart';
import '../infra/link_probe.dart';
import '../infra/prism_agent.dart';
import '../infra/pulse_station.dart';
import 'signal_lost_page.dart';

class PrismPortal extends StatefulWidget {
  const PrismPortal({
    super.key,
    required this.url,
    required this.store,
    required this.probe,
    required this.pulse,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final CircuitStore store;
  final LinkProbe probe;
  final PulseStation pulse;
  final PrismAgent agent;
  final bool coldLaunch;

  @override
  State<PrismPortal> createState() => _PrismPortalState();
}

class _PrismPortalState extends State<PrismPortal> with WidgetsBindingObserver {
  static const int _redirectRetryLimit = 2;
  static const Duration _coldSettle = Duration(milliseconds: 410);
  static const Duration _pageSettle = Duration(milliseconds: 1150);
  static const Duration _rotationSettle = Duration(milliseconds: 470);
  static const List<int> _reflowSteps = <int>[55, 190, 375, 620, 940];

  late final WebViewController _web;
  StreamSubscription<List<ConnectivityResult>>? _linkChanges;
  Timer? _rotationTimer;
  bool _viewportReady = false;
  bool _coldReloadDone = false;
  bool _offlineRouted = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Size? _lastMetrics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Inline playback is configured on the platform controller rather than
    // patched in with JavaScript after every load.
    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _web =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF0A0E1A))
          ..setUserAgent(widget.agent.identity)
          ..enableZoom(false)
          ..setNavigationDelegate(_delegate());
    final platform = _web.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }

    widget.pulse.onDestination = (url) {
      if (!mounted || !PrismConfig.hostAllowed(url)) return;
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasScheme) _web.loadRequest(uri);
    };
    _linkChanges = widget.probe.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        // Connectivity is definitively gone. Route straight out — probing
        // first stalls for seconds and lets WKWebView paint its own error
        // page in the meantime.
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _web.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainPending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Let immersive mode settle in the phone's *actual* orientation before the
  /// WebView mounts, so WKWebView measures the right viewport. Deliberately no
  /// landscape nudge: that made cold-start push links open sideways and flip.
  Future<void> _settleColdViewport() async {
    _enterImmersive();
    await Future<void>.delayed(_coldSettle);
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _web.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final size = View.of(context).physicalSize;
    final flipped =
        _lastMetrics != null &&
        ((_lastMetrics!.width < _lastMetrics!.height) !=
            (size.width < size.height));
    _lastMetrics = size;
    if (!flipped) return;
    _enterImmersive();
    // WKWebView holds the pre-rotation viewport width for a few hundred ms,
    // so the page renders at the wrong width right after the flip. Nudge it
    // repeatedly while the native frame settles.
    _rotationTimer?.cancel();
    for (final step in _reflowSteps) {
      Timer(Duration(milliseconds: step), () {
        if (!mounted) return;
        _web
            .runJavaScript(
              'window.dispatchEvent(new Event("orientationchange"));'
              'window.dispatchEvent(new Event("resize"));'
              'window.visualViewport?.dispatchEvent(new Event("resize"));',
            )
            .catchError((_) {});
      });
    }
    _rotationTimer = Timer(_rotationSettle, () {
      if (!mounted) return;
      _applyShellScript();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _drainPending();
    }
  }

  Future<void> _drainPending() async {
    final value = await widget.store.consumePending();
    if (!mounted || value == null) return;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) await _web.loadRequest(uri);
  }

  NavigationDelegate _delegate() {
    return NavigationDelegate(
      onPageStarted: (url) => _lastMainUrl = url,
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _applyShellScript();
        Future<void>.delayed(_pageSettle, () async {
          if (!mounted) return;
          setState(() {});
          await _web.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _applyShellScript();
          if (widget.coldLaunch && !_coldReloadDone) {
            _coldReloadDone = true;
            await _web.reload();
          }
        });
      },
      onWebResourceError: (error) {
        // -999 means a newer navigation superseded this one.
        if (error.errorCode == -999) return;
        final message = error.description.toLowerCase();
        final redirectLoop =
            error.errorCode == -1007 ||
            message.contains('too_many_redirects') ||
            message.contains('too many redirects');
        if (redirectLoop &&
            _lastMainUrl != null &&
            _redirectAttempts < _redirectRetryLimit) {
          _redirectAttempts++;
          _web.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        // WKWebView sometimes reports isForMainFrame as null on the main
        // navigation; treating null as a sub-frame silently froze the app.
        if (!(error.isForMainFrame ?? true)) return;
        _goOfflineIfProbeAgrees();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        final scheme = uri.scheme.toLowerCase();
        if (scheme == 'javascript') return NavigationDecision.prevent;
        if (const <String>{
          'http',
          'https',
          'about',
          'data',
          'blob',
        }.contains(scheme)) {
          if (request.isMainFrame) {
            if (scheme == 'http' || scheme == 'https') {
              if (!PrismConfig.hostAllowed(request.url)) {
                return NavigationDecision.prevent;
              }
            }
            _lastMainUrl = request.url;
          }
          return NavigationDecision.navigate;
        }
        if (const <String>{'tel', 'mailto'}.contains(scheme)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return NavigationDecision.prevent;
      },
    );
  }

  /// A load error can be transient, so confirm the outage before leaving.
  Future<void> _goOfflineIfProbeAgrees() async {
    if (_offlineRouted) return;
    bool online = true;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineRouted || !mounted) return;
    _offlineRouted = true;
    String current;
    try {
      current = await _web.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SignalLostPage(
          probe: widget.probe,
          retryBuilder: (_) => PrismPortal(
            url: current,
            store: widget.store,
            probe: widget.probe,
            pulse: widget.pulse,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  Future<void> _openGame() async {
    // The portal boot skips this warmup, so do it here before the menu reads
    // saved progress. Both services are idempotent.
    await Future.wait<void>(<Future<void>>[
      SaveService.instance.init(),
      AudioService.instance.init(),
    ]);
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(Routes.mainMenu);
  }

  /// One idempotent bundle behind a single sentinel: viewport lock, inset
  /// neutralisation, tap polish, keyboard reveal, readable input sizing and
  /// the app's scrollbar tint. Re-applied after SPA navigations and rotation.
  void _applyShellScript() {
    _web.runJavaScript(r'''
(() => {
  const w = window;
  // Rewriting the viewport while the keyboard is up races the compositor and
  // makes the field jitter, so the whole patch stands down until it closes.
  const keyboardOpen = () => {
    const vv = w.visualViewport;
    return !!vv && vv.height < w.innerHeight * 0.75;
  };
  const apply = () => {
    if (keyboardOpen()) return;
    const host = document.head || document.documentElement;
    if (!host) return;
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) {
      vp = document.createElement('meta');
      vp.setAttribute('name', 'viewport');
      host.appendChild(vp);
    }
    vp.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
    let sheet = document.getElementById('rdp-shell-rules');
    if (!sheet) {
      sheet = document.createElement('style');
      sheet.id = 'rdp-shell-rules';
      host.appendChild(sheet);
    }
    sheet.textContent = [
      ':root{',
      '--safe-area-inset-top:0px!important;',
      '--safe-area-inset-right:0px!important;',
      '--safe-area-inset-bottom:0px!important;',
      '--safe-area-inset-left:0px!important;',
      '--sat:0px!important;--sar:0px!important;',
      '--sab:0px!important;--sal:0px!important;',
      '--safe-top:0px!important;--safe-right:0px!important;',
      '--safe-bottom:0px!important;--safe-left:0px!important;}',
      'html,body{overscroll-behavior:none!important;',
      'overscroll-behavior-y:none!important;',
      'scrollbar-color:#35e9ff #12182b;scrollbar-width:thin;}',
      '*{-webkit-tap-highlight-color:transparent!important;}',
      '*:not(input):not(textarea):not([contenteditable="true"])',
      '{-webkit-touch-callout:none!important;}',
      'input,textarea,select,[contenteditable="true"]',
      '{font-size:max(16px,1em)!important;}'
    ].join('');
  };
  apply();
  if (w.__rdpShell) return;
  w.__rdpShell = true;
  const later = () => { w.setTimeout(apply, 180); w.setTimeout(apply, 700); };
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const result = original.apply(this, args);
      later();
      return result;
    };
  });
  w.addEventListener('popstate', later);
  w.setInterval(apply, 3300);
  const stop = (e) => e.preventDefault();
  ['gesturestart', 'gesturechange', 'gestureend'].forEach((type) =>
    document.addEventListener(type, stop, {passive: false}));
  document.addEventListener('touchmove', (e) => {
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive: false});
  let lastTap = 0;
  document.addEventListener('touchend', (e) => {
    const now = Date.now();
    if (now - lastTap <= 300) e.preventDefault();
    lastTap = now;
  }, {passive: false});
  const editable = (node) => !!node && node.matches &&
    node.matches('input, textarea, select, [contenteditable="true"]');
  document.addEventListener('focusin', (event) => {
    if (!editable(event.target)) return;
    w.setTimeout(() => {
      const active = document.activeElement;
      if (editable(active)) {
        active.scrollIntoView({behavior: 'auto', block: 'nearest'});
      }
    }, 360);
  }, true);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rotationTimer?.cancel();
    _linkChanges?.cancel();
    widget.pulse.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pad for the notch and side cutouts *and* the home indicator, in both
    // orientations. Cold start reads viewPadding too — falling back to zero
    // loses the bottom inset while immersive mode settles.
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _web.canGoBack()) await _web.goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        resizeToAvoidBottomInset: false,
        body: !_viewportReady
            ? const ColoredBox(color: Color(0xFF0A0E1A))
            : Stack(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(
                      top: safe.top,
                      bottom: safe.bottom,
                      left: safe.left,
                      right: safe.right,
                    ),
                    child: WebViewWidget(controller: _web),
                  ),
                  if (PrismConfig.showGameEscape)
                    Positioned(
                      right: safe.right + 10,
                      bottom: safe.bottom + 10,
                      child: _GameEscape(onTap: _openGame),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Small pill that drops back into the puzzle game from the portal shell.
class _GameEscape extends StatelessWidget {
  const _GameEscape({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.82,
      child: Material(
        color: const Color(0xFF12182B),
        borderRadius: BorderRadius.circular(20),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.videogame_asset_rounded,
                  size: 16,
                  color: Color(0xFF35E9FF),
                ),
                SizedBox(width: 6),
                Text(
                  'Play',
                  style: TextStyle(
                    color: Color(0xFFF3F7FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
