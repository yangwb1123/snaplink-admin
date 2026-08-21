part of 'snaplink_admin_api.dart';

Map<String, dynamic> _decode(http.Response response) {
  return decodeSnaplinkAdminPayload(response.body);
}

extension SnaplinkAdminApiRequest on SnaplinkAdminApi {
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? contentType,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': path.startsWith('/api/v1/scim/')
          ? 'application/scim+json'
          : 'application/json',
      ...?extraHeaders,
      'Authorization': 'Bearer $accessToken',
      if (body != null) 'Content-Type': contentType ?? 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final canRetry = method == 'GET';

    // Only safe reads are retried automatically. Replaying a POST/PATCH after
    // an ambiguous network failure can duplicate a change even when the
    // browser never received the first successful response.
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final responseFuture = switch (method) {
          'GET' => _http.get(uri, headers: headers),
          'POST' => _http.post(uri, headers: headers, body: encodedBody),
          'PUT' => _http.put(uri, headers: headers, body: encodedBody),
          'PATCH' => _http.patch(uri, headers: headers, body: encodedBody),
          'DELETE' => _http.delete(uri, headers: headers, body: encodedBody),
          _ => throw ArgumentError.value(
            method,
            'method',
            'Unsupported HTTP method',
          ),
        };
        final response = await responseFuture.timeout(requestTimeout);
        final data = _decode(response);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (method != 'GET') {
            _recordAudit(method, path, response.statusCode);
            _fireDataChanged(method, path);
          }
          return data;
        }
        // Retry server-side read failures, never an unsafe mutation.
        if (canRetry && response.statusCode >= 500 && attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        if (response.statusCode == 401) {
          onUnauthorized?.call();
        }
        throw snaplinkAdminError(response.statusCode, data);
      } on TimeoutException catch (_) {
        if (canRetry && attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      } catch (e) {
        if (e is SnaplinkAdminApiError) rethrow;
        if (canRetry && attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
  }
}
