import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sso_admin/api/snaplink_admin_error.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';

/// Binary attachment transport for sensitive and potentially large exports.
///
/// Keeping downloads outside the JSON client prevents subject PII and archive
/// bytes from entering generic response panels, caches, or clipboard actions.
class SnaplinkAdminDownloadTransport {
  final String baseUrl;
  final String accessToken;
  final http.Client httpClient;
  final Duration requestTimeout;
  final void Function()? onUnauthorized;

  const SnaplinkAdminDownloadTransport({
    required this.baseUrl,
    required this.accessToken,
    required this.httpClient,
    required this.requestTimeout,
    this.onUnauthorized,
  });

  Future<SnaplinkAdminDownload> post(
    String path, {
    Object? body,
    String? contentType,
  }) async {
    final response = await httpClient
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(body: body, contentType: contentType),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _decodeResponse(response);
  }

  Future<SnaplinkAdminDownload> get(
    String path, {
    Map<String, String>? query,
    required int maxRetries,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await httpClient
            .get(uri, headers: _headers())
            .timeout(requestTimeout);
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await Future<void>.delayed(_retryDelay(attempt));
          continue;
        }
        return _decodeResponse(response);
      } on TimeoutException {
        if (attempt >= maxRetries) rethrow;
        await Future<void>.delayed(_retryDelay(attempt));
      } catch (error) {
        if (error is SnaplinkAdminApiError || attempt >= maxRetries) rethrow;
        await Future<void>.delayed(_retryDelay(attempt));
      }
    }
  }

  Map<String, String> _headers({Object? body, String? contentType}) => {
    'Accept': 'application/octet-stream, application/json',
    'Authorization': 'Bearer $accessToken',
    if (body != null) 'Content-Type': contentType ?? 'application/json',
  };

  SnaplinkAdminDownload _decodeResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return SnaplinkAdminDownload(
        bytes: response.bodyBytes,
        contentType:
            response.headers['content-type'] ?? 'application/octet-stream',
        filename: _attachmentFilename(response.headers['content-disposition']),
      );
    }
    if (response.statusCode == 401) onUnauthorized?.call();
    throw snaplinkAdminError(
      response.statusCode,
      decodeSnaplinkAdminPayload(response.body),
    );
  }

  static Duration _retryDelay(int attempt) =>
      Duration(milliseconds: pow(2, attempt).toInt() * 500);

  static String? _attachmentFilename(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final encoded = RegExp(
      r"filename\*\s*=\s*UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    final plain = RegExp(
      r'filename\s*=\s*(?:"([^"]*)"|([^;\s]+))',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    var filename = encoded?.group(1) ?? plain?.group(1) ?? plain?.group(2);
    if (filename == null || filename.trim().isEmpty) return null;
    if (encoded != null) {
      try {
        filename = Uri.decodeComponent(filename);
      } on FormatException {
        // Keep the encoded value and sanitize it below.
      }
    }
    final safe = filename!.replaceAll(RegExp(r'[\\/\x00-\x1f]'), '_').trim();
    return safe.isEmpty ? null : safe;
  }
}
