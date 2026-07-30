import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../infra/circuit_store.dart';
import '../infra/pulse_station.dart';
import 'glow_button.dart';

/// Opt-in promo shown before the portal. Both choices move on; declining only
/// snoozes the offer.
class PulseInvite extends StatefulWidget {
  const PulseInvite({
    super.key,
    required this.store,
    required this.pulse,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final CircuitStore store;
  final PulseStation pulse;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<PulseInvite> createState() => _PulseInviteState();
}

class _PulseInviteState extends State<PulseInvite> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The loading screen locks portrait before routing here; re-enable
    // landscape so this screen rotates like the portal that follows it.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.pulse.askPermission();
    final token = widget.pulse.token;
    if (granted && token != null && token.isNotEmpty) {
      await widget.onTokenReady?.call(token);
    }
    if (!granted) await widget.store.snoozeInvite();
    _moveOn();
  }

  Future<void> _decline() async {
    if (_working) return;
    setState(() => _working = true);
    await widget.store.snoozeInvite();
    _moveOn();
  }

  void _moveOn() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background = landscape
        ? 'assets/beacon/notify_h.jpg'
        : 'assets/beacon/notify_v.jpg';
    final width = landscape
        ? (media.size.width * 0.42).clamp(320.0, 560.0)
        : (media.size.width * 0.80).clamp(280.0, 440.0);

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
            alignment: Alignment(0, landscape ? 0.78 : 0.86),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                GlowButton(
                  label: 'ALLOW',
                  width: width,
                  height: landscape ? 68 : 76,
                  fontSize: landscape ? 22 : 25,
                  busy: _working,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 12 : 16),
                GlowButton(
                  label: 'NOT NOW',
                  width: width * 0.9,
                  height: landscape ? 58 : 64,
                  fontSize: landscape ? 19 : 21,
                  secondary: true,
                  onTap: _decline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
