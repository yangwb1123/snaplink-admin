import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sso_admin/api/snaplink_admin_error.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';

/// Bearer-authenticated Server-Sent Events transport for admin notifications.
///
/// `EventSource` cannot attach the console's bearer token, so this service
/// parses a streamed Fetch response. Only establishing the connection is
/// subject to [requestTimeout]; a healthy long-lived stream is not.
class SnaplinkAdminEventStream {
  final String baseUrl;
  final String accessToken;
  final http.Client httpClient;
  final Duration requestTimeout;
  final void Function()? onUnauthorized;

  const SnaplinkAdminEventStream({
    required this.baseUrl,
    required this.accessToken,
    required this.httpClient,
    required this.requestTimeout,
    this.onUnauthorized,
  });

  Stream<SnaplinkAdminEvent> open({
    String? eventTypes,
    String? tenantId,
    String? lastEventId,
  }) async* {
    final query = <String, String>{
      if (eventTypes?.trim().isNotEmpty ?? false) 'event_types': eventTypes!,
      if (tenantId?.trim().isNotEmpty ?? false) 'tenant_id': tenantId!,
    };
    final request =
        http.Request(
            'GET',
            Uri.parse(
              '$baseUrl/api/v1/admin/events/stream',
            ).replace(queryParameters: query.isEmpty ? null : query),
          )
          ..headers.addAll({
            'Accept': 'text/event-stream',
            'Authorization': 'Bearer $accessToken',
            if (lastEventId?.trim().isNotEmpty ?? false)
              'Last-Event-ID': lastEventId!,
          });
    final response = await httpClient.send(request).timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = await response.stream.bytesToString().timeout(
        requestTimeout,
      );
      if (response.statusCode == 401) onUnauthorized?.call();
      throw snaplinkAdminError(
        response.statusCode,
        decodeSnaplinkAdminPayload(payload),
      );
    }

    String? id;
    var type = 'message';
    final dataLines = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          yield _event(id, type, dataLines);
        }
        id = null;
        type = 'message';
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      final separator = line.indexOf(':');
      final field = separator < 0 ? line : line.substring(0, separator);
      var value = separator < 0 ? '' : line.substring(separator + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'id':
          id = value;
        case 'event':
          type = value;
        case 'data':
          dataLines.add(value);
      }
    }
    if (dataLines.isNotEmpty) yield _event(id, type, dataLines);
  }

  static SnaplinkAdminEvent _event(
    String? id,
    String type,
    List<String> dataLines,
  ) {
    return SnaplinkAdminEvent(
      id: id,
      type: type,
      data: decodeSnaplinkAdminPayload(dataLines.join('\n')),
    );
  }
}
