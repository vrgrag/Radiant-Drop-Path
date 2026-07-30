import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/prism_config.dart';
import 'circuit_store.dart';

@pragma('vm:entry-point')
Future<void> relayBackgroundMessage(RemoteMessage _) async {}

class PulseStation {
  PulseStation(this._store, {required this.enabled});

  final CircuitStore _store;
  final bool enabled;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;
    final initial = await messaging.getInitialMessage().timeout(
      const Duration(seconds: 6),
      onTimeout: () => null,
    );
    final initialUrl = initial == null ? null : _destinationIn(initial.data);
    if (initialUrl != null) await _store.stashPending(initialUrl);

    FirebaseMessaging.onBackgroundMessage(relayBackgroundMessage);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = _destinationIn(message.data);
      if (url == null) return;
      final callback = onDestination;
      if (callback == null) {
        _store.stashPending(url);
      } else {
        callback(url);
      }
    });
    await _awaitApnsToken();
    _token = await messaging.getToken();
  }

  String? _destinationIn(Map<String, dynamic> payload) {
    for (final key in const <String>[
      'deep_link',
      'target',
      'url',
      'deeplink',
      'link',
    ]) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        final candidate = value.trim();
        return PrismConfig.hostAllowed(candidate) ? candidate : null;
      }
    }
    for (final container in const <String>['payload', 'data']) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _destinationIn(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _awaitApnsToken({int attempts = 9}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 380));
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled || _store.inviteBlockedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;
    final status = (await messaging.getNotificationSettings())
        .authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _store.markInviteBlockedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _requestPermission().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _requestPermission() async {
    final messaging = _messaging;
    if (!enabled || messaging == null) return false;
    final result = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _store.setInviteGranted(accepted);
    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _store.markInviteBlockedByOs();
    }
    if (accepted) {
      await _awaitApnsToken(attempts: 16);
      _token = await messaging.getToken();
      final token = _token;
      if (token != null && token.isNotEmpty) onTokenChanged?.call(token);
    }
    return accepted;
  }
}
