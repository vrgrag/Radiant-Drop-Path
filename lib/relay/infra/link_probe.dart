import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class LinkProbe {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Resolves well-known hosts rather than our own domain, so a VPN or a
  /// freshly registered app domain never reads as "offline". Every lookup is
  /// time-boxed so a retry can not hang indefinitely.
  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    for (final host in const <String>['icloud.com', 'quad9.net']) {
      try {
        final records = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 4));
        if (records.any((record) => record.rawAddress.isNotEmpty)) {
          return true;
        }
      } catch (_) {
        // Fall through to the next host before declaring the link down.
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
