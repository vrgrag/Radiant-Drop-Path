import 'dart:async';
import 'dart:io';

import 'config/prism_config.dart';
import 'core/relay_models.dart';
import 'core/relay_trace.dart';
import 'infra/circuit_store.dart';
import 'infra/cold_link_reader.dart';
import 'infra/link_probe.dart';
import 'infra/prism_agent.dart';
import 'infra/pulse_station.dart';
import 'infra/relay_exchange.dart';
import 'infra/source_trace.dart';

/// Decides once per install whether this device sees the portal or the game,
/// and re-checks on later launches.
class BeamRouter {
  BeamRouter({
    required this.store,
    required this.probe,
    required this.trace,
    required this.exchange,
    required this.pulse,
    required this.agent,
    required this.runtimeEnabled,
  });

  final CircuitStore store;
  final LinkProbe probe;
  final SourceTrace trace;
  final RelayExchange exchange;
  final PulseStation pulse;
  final PrismAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && PrismConfig.relayReady;

  Future<RelayStop>? _pending;

  /// De-duplicates *concurrent* callers only — the loading screen can rebuild
  /// during startup and would otherwise fire two attribution runs. The future
  /// is dropped once it settles, so a later Retry re-runs the full pipeline
  /// instead of replaying a stale offline result forever.
  Future<RelayStop> resolve({required void Function(double value) onProgress}) =>
      _pending ??= _resolve(
        onProgress,
      ).whenComplete(() => _pending = null);

  Future<RelayStop> _resolve(void Function(double) progress) async {
    if (!enabled) {
      relayTrace(
        () =>
            '[RDP.ROUTER] disabled runtime=$runtimeEnabled '
            'ready=${PrismConfig.relayReady}',
      );
      progress(1);
      return const NativeStop();
    }

    relayTrace(() => '[RDP.ROUTER] resolve start route=${store.route}');
    pulse.onTokenChanged = _resendWithToken;

    // A notification tap that cold-started the app wins over everything else.
    // Reading it later loses the destination to a timeout race and drops the
    // user on the menu instead.
    final coldLink = await ColdLinkReader.consume();
    if (coldLink != null) {
      await store.saveRoute(BeamRoute.portal);
      await store.consumePending();
      unawaited(_catchUpInBackground());
      progress(1);
      return PortalStop(coldLink, coldLaunch: true);
    }

    progress(0.14);
    return switch (store.route) {
      BeamRoute.undecided => _firstLaunch(progress),
      BeamRoute.portal => _returningPortal(progress),
      BeamRoute.native => _returningNative(progress),
    };
  }

  /// First launch. Note what is *not* here: no path commits to the game on a
  /// network failure. Only a successful reply that carries no destination
  /// does — otherwise an offline install would trap a paid user in the game.
  Future<RelayStop> _firstLaunch(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      relayTrace(() => '[RDP.ROUTER] first launch: no interface');
      return const OfflineStop();
    }
    progress(0.3);
    try {
      await pulse.boot();
    } catch (_) {}
    if (!await probe.canReachNetwork()) {
      relayTrace(() => '[RDP.ROUTER] first launch: unreachable');
      return const OfflineStop();
    }
    progress(0.5);
    await trace.awaitSignals();
    progress(0.74);
    final reply = await _askRelay();
    progress(1);
    relayTrace(
      () => '[RDP.ROUTER] first launch: destination=${reply.hasDestination}',
    );
    if (reply.hasDestination) {
      await store.saveRoute(BeamRoute.portal);
      return PortalStop(reply.url!);
    }
    if (reply.accepted) {
      await store.saveRoute(BeamRoute.native);
      return const NativeStop();
    }
    return const OfflineStop();
  }

  Future<RelayStop> _returningPortal(void Function(double) progress) async {
    if (!await probe.hasInterface()) return const OfflineStop();

    final pendingPush = await store.consumePending();
    if (pendingPush != null && pendingPush.isNotEmpty) {
      progress(1);
      return PortalStop(pendingPush);
    }

    final cached = await store.savedDestination();
    if (cached != null && !store.cachedDestinationStale) {
      progress(1);
      return PortalStop(cached);
    }

    await Future.wait<void>(<Future<void>>[pulse.boot(), trace.start()]);
    if (!await probe.canReachNetwork()) return const OfflineStop();
    progress(0.64);
    await trace.awaitSignals(
      installTimeout: PrismConfig.returningSignalTimeout,
    );
    final reply = await _askRelay();
    progress(1);
    if (reply.hasDestination) return PortalStop(reply.url!);
    if (cached != null) return PortalStop(cached);
    return const OfflineStop();
  }

  Future<RelayStop> _returningNative(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const NativeStop();
    }
    await Future.wait<void>(<Future<void>>[pulse.boot(), trace.start()]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const NativeStop();
    }
    progress(0.58);
    await trace.awaitSignals();
    final reply = await _askRelay();
    progress(1);
    if (!reply.hasDestination) return const NativeStop();
    await store.saveRoute(BeamRoute.portal);
    return PortalStop(reply.url!);
  }

  Future<RelayReply> _askRelay({String? token}) async {
    final body = await trace.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? pulse.token,
    );
    return exchange.request(body);
  }

  Future<void> _catchUpInBackground() async {
    try {
      await Future.wait<void>(<Future<void>>[
        pulse.boot(),
        trace.awaitSignals(),
      ]);
      await _askRelay();
    } catch (_) {}
  }

  Future<void> _resendWithToken(String token) async {
    try {
      await _askRelay(token: token);
    } catch (_) {}
  }
}
