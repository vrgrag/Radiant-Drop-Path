import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/prism_config.dart';

/// HTTP client that presents the same browser identity as the portal WebView,
/// built from the running device rather than hardcoded.
///
/// GAME THEME CATEGORY: crash — no partner identity suffix is appended, so
/// the identity never leaves the binary as a literal.
class PrismAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _identity;

  static const String _fallbackRelease = '18.6';

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _identity = _compose(_fallbackRelease);
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _identity = _compose(_normalizedRelease(info.systemVersion));
    } catch (_) {
      _identity = _compose(_fallbackRelease);
    }
  }

  String get identity => _identity ?? _compose(_fallbackRelease);

  String _normalizedRelease(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 18) return _fallbackRelease;
    return parts.join('.');
  }

  String _compose(String release) =>
      '${PrismConfig.agentHead}${release.replaceAll('.', '_')}'
      '${PrismConfig.agentMid}$release${PrismConfig.agentTail}';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => identity);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
