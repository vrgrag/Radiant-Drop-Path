enum BeamRoute {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    BeamRoute.native => 'native',
    BeamRoute.portal => 'portal',
    BeamRoute.undecided => 'undecided',
  };

  static BeamRoute parse(String? value) => switch (value) {
    'portal' => BeamRoute.portal,
    'native' => BeamRoute.native,
    _ => BeamRoute.undecided,
  };
}

class RelayReply {
  const RelayReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory RelayReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return RelayReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory RelayReply.rejected(String reason) =>
      RelayReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class RelayStop {
  const RelayStop();
}

final class NativeStop extends RelayStop {
  const NativeStop();
}

final class PortalStop extends RelayStop {
  const PortalStop(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class OfflineStop extends RelayStop {
  const OfflineStop();
}
