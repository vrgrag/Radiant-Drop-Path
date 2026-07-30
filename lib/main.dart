import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'relay/beam_router.dart';
import 'relay/config/prism_config.dart';
import 'relay/core/relay_trace.dart';
import 'relay/infra/circuit_store.dart';
import 'relay/infra/link_probe.dart';
import 'relay/infra/prism_agent.dart';
import 'relay/infra/pulse_station.dart';
import 'relay/infra/relay_exchange.dart';
import 'relay/infra/source_trace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = CircuitStore();
  final agent = PrismAgent();
  await Future.wait<void>(<Future<void>>[store.initialize(), agent.prepare()]);

  relayTrace(
    () =>
        '[RDP.BOOT] ready=${PrismConfig.relayReady} '
        'endpoint=${PrismConfig.relayEndpoint} '
        'sender=${PrismConfig.messagingSender}',
  );

  var messagingReady = false;
  if (PrismConfig.relayReady) {
    try {
      await Firebase.initializeApp();
      messagingReady = true;
    } catch (error) {
      relayTrace(() => '[RDP.BOOT] Firebase init failed: $error');
    }
    if (messagingReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        // App Check must never gate messaging or routing.
        relayTrace(() => '[RDP.BOOT] App Check skipped: $error');
      }
    }
  }

  final probe = LinkProbe();
  // Attribution and the config request run even when Firebase failed to come
  // up; only push delivery depends on it.
  final pulse = PulseStation(store, enabled: messagingReady);
  final router = BeamRouter(
    store: store,
    probe: probe,
    trace: SourceTrace(agent),
    exchange: RelayExchange(agent, store),
    pulse: pulse,
    agent: agent,
    runtimeEnabled: PrismConfig.relayReady,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(RadiantDropPathApp(router: router));
}
