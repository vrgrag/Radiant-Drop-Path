import '../core/lumen_cipher.dart';

/// Identity, timings and backend identifiers for the relay layer.
///
/// The packed strings below come from `dart run tool/pack_relay_values.dart`.
/// Public links (privacy, support, allowed hosts) stay in plain text: they are
/// published verbatim in App Store Connect, so packing them would hide nothing.
abstract final class PrismConfig {
  static const String appTitle = 'Radiant Drop Path';
  static const String bundleId = 'com.radiantdrop.pathgame';

  /// Numeric App Store id. `store_id` is sent as `id` + this value.
  static const String iosStoreId = '6792810383';

  static const String privacyUrl =
      'https://radiantdroppath.com/privacy-policy.html';
  static const String supportUrl = 'https://radiantdroppath.com/support.html';

  /// Hosts the portal may load. Anything else — from a config reply, a cached
  /// destination or a push payload — is dropped before it reaches the WebView.
  static const List<String> allowedHostSuffixes = <String>[
    'radiantdroppath.com',
    'team-s.club',
  ];

  // ── Timings ──────────────────────────────────────────────────────────────
  static const int inviteSnoozeSeconds = 313200;
  static const int organicRecheckSeconds = 9;
  static const int savedUrlExpiryDays = 5;
  static const Duration relayTimeout = Duration(seconds: 21);
  static const Duration traceLookupTimeout = Duration(seconds: 17);
  static const Duration installSignalTimeout = Duration(seconds: 11);
  static const Duration returningSignalTimeout = Duration(seconds: 7);
  static const Duration deepLinkSignalTimeout = Duration(seconds: 6);
  static const Duration trackingPromptDelay = Duration(milliseconds: 640);
  static const double trackingAuthorizationWait = 5;

  /// Offer a way back into the game from the portal shell. Turn off only if
  /// the partner surface cannot tolerate the overlay.
  static const bool showGameEscape = true;

  // ── Packed identifiers ───────────────────────────────────────────────────
  static const String _relayEndpoint =
      'CxsZXgFbS0YTDxANEwEESgIOBBgGFQVLAAAAAREOCg8ICVoUGh8=';
  static const String _traceKey = 'LTo/GgFTJS4XKEIGPB0eRCMSQV0fNw==';
  static const String _messagingSender = 'UlpcHEtXVlpRVkRS';
  static const String _traceLookup =
      'CxsZXgFbS0YGDRAXFgReTwARBw4LGAgXTQwCQ10IChoVDxgILQsRWhFOAl1JUUI=';
  static const String _inviteHost = 'EQ4JRxMPEA0TAQRKHQEVQhkPH0YKBA==';
  static const String _agentHead =
      'LgAXRx4NBUZUQEREWgYgRh8PEVNHIj0wQwY9Rh0PAUkuPVQ=';
  static const String _agentMid =
      'QwMERRdBKQgCTjs3UjdZDjERBAQCNggHKAYZAURRUUdQQEVRUkc7ZiQsOERHDQQOBk8qSxEKC0BBOBEWAQYfQF8=';
  static const String _agentTail = 'QyICTBsNAUZQWzFVRldQfREHFRoOTltVV0Fc';

  static String get relayEndpoint => revealLumen(_relayEndpoint);
  static String get traceKey => revealLumen(_traceKey);
  static String get messagingSender => revealLumen(_messagingSender);
  static String get traceLookup => revealLumen(_traceLookup);
  static String get inviteHost => revealLumen(_inviteHost);
  static String get agentHead => revealLumen(_agentHead);
  static String get agentMid => revealLumen(_agentMid);
  static String get agentTail => revealLumen(_agentTail);

  static String get storeToken => 'id$iosStoreId';

  /// The relay needs the endpoint, the attribution key and the messaging
  /// sender id. Optional values such as [inviteHost] must never appear here —
  /// a blank optional would switch the whole layer off without a trace.
  static bool get relayReady =>
      relayEndpoint.isNotEmpty &&
      traceKey.isNotEmpty &&
      messagingSender.isNotEmpty;

  /// True when [candidate] points at a host we are willing to render.
  static bool hostAllowed(String? candidate) {
    if (candidate == null || candidate.isEmpty) return false;
    final host = Uri.tryParse(candidate)?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;
    return allowedHostSuffixes.any(
      (suffix) => host == suffix || host.endsWith('.$suffix'),
    );
  }
}
