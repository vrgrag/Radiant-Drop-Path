import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../infra/link_probe.dart';
import 'glow_button.dart';

/// Shown when the device has no usable connection. Retry rebuilds a fresh
/// widget from [retryBuilder] using this page's own mounted context, so the
/// whole pipeline runs again — a captured parent context would be defunct
/// after the pushReplacement that brought us here.
class SignalLostPage extends StatefulWidget {
  const SignalLostPage({
    super.key,
    required this.probe,
    required this.retryBuilder,
  });

  final LinkProbe probe;
  final WidgetBuilder retryBuilder;

  @override
  State<SignalLostPage> createState() => _SignalLostPageState();
}

class _SignalLostPageState extends State<SignalLostPage> {
  bool _checking = false;
  bool _stillDown = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The loading screen locks portrait before routing here, so re-enable
    // landscape or the artwork stays stuck in portrait.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _retry() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillDown = false;
    });
    bool online = false;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.retryBuilder),
      );
      return;
    }
    setState(() {
      _checking = false;
      _stillDown = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background = landscape
        ? 'assets/beacon/offline_h.jpg'
        : 'assets/beacon/offline_v.jpg';
    final width = landscape
        ? (media.size.width * 0.36).clamp(300.0, 520.0)
        : (media.size.width * 0.70).clamp(240.0, 400.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            background,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Align(
            alignment: Alignment(0, landscape ? 0.74 : 0.78),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                GlowButton(
                  label: 'TRY AGAIN',
                  icon: Icons.refresh_rounded,
                  width: width,
                  height: landscape ? 68 : 74,
                  fontSize: landscape ? 21 : 23,
                  busy: _checking,
                  onTap: _retry,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: _stillDown
                      ? const Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: Text(
                            'Still offline',
                            style: TextStyle(
                              color: Color(0xFFF3F7FF),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              shadows: <Shadow>[
                                Shadow(color: Colors.black, blurRadius: 6),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
