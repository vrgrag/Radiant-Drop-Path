import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/prism_config.dart';
import '../core/relay_models.dart';

class CircuitStore {
  static const String _routeKey = 'rdp.beam.route';
  static const String _replyExpiryKey = 'rdp.beam.reply_expiry';
  static const String _cachedAtKey = 'rdp.beam.cached_at';
  static const String _inviteKey = 'rdp.beam.invite_after';
  static const String _inviteGrantedKey = 'rdp.beam.invite_granted';
  static const String _inviteBlockedKey = 'rdp.beam.invite_blocked';
  static const String _destinationKey = 'rdp.beam.vault.destination';
  static const String _pendingKey = 'rdp.beam.vault.pending';

  final FlutterSecureStorage _vault = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  BeamRoute get route => BeamRoute.parse(_prefs.getString(_routeKey));

  Future<void> saveRoute(BeamRoute route) =>
      _prefs.setString(_routeKey, route.storageValue);

  Future<String?> savedDestination() async {
    try {
      final value = await _vault.read(key: _destinationKey);
      if (value == null || !PrismConfig.hostAllowed(value)) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheDestination(String url, int? expiresAt) async {
    if (!PrismConfig.hostAllowed(url)) return;
    try {
      await _vault.write(key: _destinationKey, value: url);
      await _prefs.setInt(_cachedAtKey, _now);
      if (expiresAt != null) {
        await _prefs.setInt(_replyExpiryKey, expiresAt);
      } else {
        await _prefs.remove(_replyExpiryKey);
      }
    } catch (_) {}
  }

  /// A cached destination is stale once the server-supplied expiry passes, and
  /// unconditionally after [PrismConfig.savedUrlExpiryDays] — a URL handed out
  /// by a long-past config response must never keep loading forever.
  bool get cachedDestinationStale {
    final cachedAt = _prefs.getInt(_cachedAtKey);
    if (cachedAt == null) return true;
    const maxAge = PrismConfig.savedUrlExpiryDays * 86400;
    if (_now - cachedAt >= maxAge) return true;
    final expiry = _prefs.getInt(_replyExpiryKey);
    return expiry != null && _now >= expiry;
  }

  Future<void> stashPending(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || !PrismConfig.hostAllowed(trimmed)) return;
    try {
      await _vault.write(key: _pendingKey, value: trimmed);
    } catch (_) {}
  }

  Future<String?> consumePending() async {
    try {
      final value = await _vault.read(key: _pendingKey);
      if (value != null) await _vault.delete(key: _pendingKey);
      if (value == null || !PrismConfig.hostAllowed(value)) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get inviteGranted => _prefs.getBool(_inviteGrantedKey) ?? false;
  bool get inviteBlockedByOs => _prefs.getBool(_inviteBlockedKey) ?? false;

  Future<void> setInviteGranted(bool value) =>
      _prefs.setBool(_inviteGrantedKey, value);

  Future<void> markInviteBlockedByOs() =>
      _prefs.setBool(_inviteBlockedKey, true);

  bool get shouldOfferInvite {
    if (inviteGranted || inviteBlockedByOs) return false;
    final after = _prefs.getInt(_inviteKey);
    return after == null || _now >= after;
  }

  Future<void> snoozeInvite() =>
      _prefs.setInt(_inviteKey, _now + PrismConfig.inviteSnoozeSeconds);

  int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
