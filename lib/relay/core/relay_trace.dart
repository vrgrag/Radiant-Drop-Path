import 'package:flutter/foundation.dart';

/// Debug-only tracing. The `assert` wrapper means the closure — and therefore
/// the message text — is stripped from release builds entirely.
void relayTrace(String Function() message) {
  // Single line on purpose: the release-stripping audit greps for a
  // debugPrint that is not guarded by an assert on the same line.
  assert(() { debugPrint(message()); return true; }());
}
