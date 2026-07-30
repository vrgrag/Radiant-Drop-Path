import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/prism_config.dart';

/// Reads the destination captured by `SceneDelegate` when the app was launched
/// by tapping a notification. The key must stay in sync with
/// `SceneDelegate.coldLinkKey`, which carries the `flutter.` prefix that the
/// shared-preferences plugin adds on iOS.
class ColdLinkReader {
  static const String _key = 'rdp_cold_link';

  /// One-shot: the value is cleared as soon as it is read, and dropped unless
  /// its host is on the allow list.
  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key)?.trim();
      if (value == null || value.isEmpty) return null;
      await prefs.remove(_key);
      return PrismConfig.hostAllowed(value) ? value : null;
    } catch (_) {
      return null;
    }
  }
}
