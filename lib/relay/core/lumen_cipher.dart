import 'dart:convert';

/// At-rest obfuscation for the handful of backend identifiers the relay layer
/// needs. Values are stored base64-encoded and XOR-masked with the bundle
/// identifier, which the OS already publishes in `Info.plist` — no extra key
/// material ships for this.
///
/// Regenerate every packed string with `dart run tool/pack_relay_values.dart`
/// whenever [_maskSeed] changes; a stale string decodes to garbage silently.
const String _maskSeed = 'com.radiantdrop.pathgame';

String revealLumen(String packed) {
  if (packed.isEmpty) return '';
  final data = base64Decode(packed);
  final mask = utf8.encode(_maskSeed);
  return utf8.decode(
    List<int>.generate(data.length, (i) => data[i] ^ mask[i % mask.length]),
  );
}
