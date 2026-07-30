import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/prism_config.dart';
import '../core/relay_trace.dart';
import 'prism_agent.dart';

class SourceTrace {
  SourceTrace(this._agent);

  final PrismAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _startFuture;
  final Completer<void> _installReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (!PrismConfig.relayReady) {
      _releaseWaiters();
      return;
    }
    try {
      await _promptForTrackingIfNeeded();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: PrismConfig.traceKey,
          appId: PrismConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization:
              PrismConfig.trackingAuthorizationWait,
        ),
      );
      _sdk = sdk;
      sdk.onInstallConversionData(_acceptInstall);
      sdk.onAppOpenAttribution((raw) => _reopen = _flatten(raw));
      sdk.onDeepLinking((result) {
        final event = result.deepLink?.clickEvent;
        if (event != null) _deepLink = Map<String, dynamic>.from(event);
        if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      relayTrace(() => '[RDP.TRACE] init failed: $error');
      _releaseWaiters();
    }
  }

  Future<void> _promptForTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(PrismConfig.trackingPromptDelay);
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _acceptInstall(dynamic raw) async {
    try {
      final received = _flatten(raw);
      final status = received['status']?.toString().toLowerCase();
      // When AppsFlyer cannot reach its servers — an ad-blocking VPN
      // blackholing *.appsflyersdk.com, say — it hands back a
      // {status: failure, data: "Request failed"} map. Merging that into the
      // payload would poison the whole request, so treat it as "no data".
      final failed =
          status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      relayTrace(
        () =>
            '[RDP.TRACE] conversion status=$status '
            'af_status=${received['af_status']} keys=${received.keys.toList()}',
      );
      if (failed) {
        _install = <String, dynamic>{};
      } else if (received['af_status'] == 'Organic') {
        // A paid install occasionally reports Organic on the first callback;
        // re-ask the lookup endpoint once before believing it.
        await Future<void>.delayed(
          const Duration(seconds: PrismConfig.organicRecheckSeconds),
        );
        _install = await _lookupConversion() ?? received;
      } else {
        _install = received;
      }
    } catch (error) {
      relayTrace(() => '[RDP.TRACE] conversion parse error: $error');
      _install = <String, dynamic>{};
    } finally {
      if (!_installReady.isCompleted) _installReady.complete();
    }
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final payload = map['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : map;
  }

  Future<Map<String, dynamic>?> _lookupConversion() async {
    final uid = await traceId();
    if (uid == null || uid.isEmpty) return null;
    try {
      // The iOS lookup is keyed by the numeric App Store id in the path
      // (`…/v5.0/id<storeId>?device_id=…`). Passing the bundle id, or the id
      // as a query parameter, comes back empty.
      final base = PrismConfig.traceLookup;
      final root = base.endsWith('/') ? base : '$base/';
      final uri = Uri.parse(
        '$root${PrismConfig.storeToken}?device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${PrismConfig.traceKey}',
            },
          )
          .timeout(PrismConfig.traceLookupTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({Duration? installTimeout}) async {
    await start();
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(
        installTimeout ?? PrismConfig.installSignalTimeout,
        onTimeout: () {},
      ),
      _deepLinkReady.future.timeout(
        PrismConfig.deepLinkSignalTimeout,
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> traceId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Builds the flat request body: every attribution field verbatim, plus the
  /// device-side fields the backend expects.
  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    if (_reopen != null) {
      _reopen!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }
    if (_deepLink != null) {
      _deepLink!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }

    body['af_id'] = await traceId() ?? body['af_id'] ?? '';
    body['bundle_id'] = PrismConfig.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = PrismConfig.storeToken;
    body['locale'] = locale;
    // Omitted entirely rather than sent blank when the token is not ready —
    // an empty string reads as a valid token on the backend.
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        PrismConfig.messagingSender.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = PrismConfig.messagingSender;
    }

    if (Platform.isIOS) {
      try {
        if (await AppTrackingTransparency.trackingAuthorizationStatus ==
            TrackingStatus.authorized) {
          final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body['sub_id_10'] = idfa;
          }
        }
      } catch (_) {}
    }
    relayTrace(() => '[RDP.TRACE] payload ${jsonEncode(body)}');
    return body;
  }

  void _releaseWaiters() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
