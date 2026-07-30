import 'dart:convert';

import '../config/prism_config.dart';
import '../core/relay_models.dart';
import '../core/relay_trace.dart';
import 'circuit_store.dart';
import 'prism_agent.dart';

class RelayExchange {
  RelayExchange(this._agent, this._store);

  final PrismAgent _agent;
  final CircuitStore _store;

  Future<RelayReply> request(Map<String, dynamic> payload) async {
    if (!PrismConfig.relayReady) {
      return RelayReply.rejected('configuration_unavailable');
    }
    try {
      relayTrace(() => '[RDP.EXCHANGE] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(PrismConfig.relayEndpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(PrismConfig.relayTimeout);
      relayTrace(
        () => '[RDP.EXCHANGE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return RelayReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return RelayReply.rejected('unreadable_response');
      final reply = RelayReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination && !PrismConfig.hostAllowed(reply.url)) {
        relayTrace(() => '[RDP.EXCHANGE] destination host rejected');
        return RelayReply.rejected('host_not_allowed');
      }
      if (reply.hasDestination) {
        await _store.cacheDestination(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      relayTrace(() => '[RDP.EXCHANGE] failed: $error');
      return RelayReply.rejected('network_failure');
    }
  }
}
