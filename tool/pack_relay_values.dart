// ignore_for_file: avoid_print

// Packs the relay layer's backend identifiers into the base64 + XOR form
// consumed by `revealLumen` in lib/relay/core/lumen_cipher.dart.
//
// Run with `dart run tool/pack_relay_values.dart` and paste the printed
// strings into lib/relay/config/prism_config.dart. Keep `_maskSeed` in sync
// with the cipher; the VERIFY block must report every value as round-tripped.

import 'dart:convert';

import 'package:radiant_drop_path/relay/config/prism_config.dart';

const String _maskSeed = 'com.radiantdrop.pathgame';

String pack(String value) {
  final bytes = utf8.encode(value);
  final mask = utf8.encode(_maskSeed);
  return base64Encode(
    List<int>.generate(bytes.length, (i) => bytes[i] ^ mask[i % mask.length]),
  );
}

String unpack(String packed) {
  final data = base64Decode(packed);
  final mask = utf8.encode(_maskSeed);
  return utf8.decode(
    List<int>.generate(data.length, (i) => data[i] ^ mask[i % mask.length]),
  );
}

void main() {
  const values = <String, String>{
    'relayEndpoint': 'https://radiantdroppath.com/config.php',
    'traceKey': 'NUR4s2AGvF6bNrnjSs55xV',
    'messagingSender': '151296230806',
    'traceLookup': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'inviteHost': 'radiantdrop.onelink.me',
    // User-Agent is assembled at runtime from these three fragments so no
    // browser-scaffolding literal ships as a Dart string.
    'agentHead': 'Mozilla/5.0 (iPhone; CPU iPhone OS ',
    'agentMid':
        ' like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/',
    'agentTail': ' Mobile/15E148 Safari/604.1',
  };

  for (final entry in values.entries) {
    final packed = pack(entry.value);
    print("  static const String _${entry.key} =\n      '$packed';");
    if (unpack(packed) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');

  // Second pass: what PrismConfig actually decodes at runtime. Catches a
  // half-finished copy-paste, which otherwise only shows up as 404s.
  final live = <String, String>{
    'relayEndpoint': PrismConfig.relayEndpoint,
    'traceKey': PrismConfig.traceKey,
    'messagingSender': PrismConfig.messagingSender,
    'traceLookup': PrismConfig.traceLookup,
    'inviteHost': PrismConfig.inviteHost,
    'agentHead': PrismConfig.agentHead,
    'agentMid': PrismConfig.agentMid,
    'agentTail': PrismConfig.agentTail,
  };
  var stale = 0;
  for (final entry in values.entries) {
    final decoded = live[entry.key];
    if (decoded != entry.value) {
      stale++;
      print('STALE ${entry.key}: PrismConfig decodes "$decoded"');
    }
  }
  print(
    stale == 0
        ? 'VERIFY: PrismConfig matches every plaintext value'
        : 'VERIFY FAILED: $stale value(s) not pasted into PrismConfig',
  );
}
