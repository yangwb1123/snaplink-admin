import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/product_api_origin.dart';

/// Bearer-authenticated user leg of RFC 8628 device authorization.
class DeviceVerifyApi {
  final http.Client _http;
  final Uri _baseUri;
  final Duration requestTimeout;

  DeviceVerifyApi({
    http.Client? httpClient,
    Uri? baseUri,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client(),
       _baseUri = baseUri ?? ProductApiOrigin.baseUri;

  static String normalizeUserCode(String value) {
    final compact = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final bounded = compact.length > 8 ? compact.substring(0, 8) : compact;
    if (bounded.length <= 4) return bounded;
    return '${bounded.substring(0, 4)}-${bounded.substring(4)}';
  }

  Future<Map<String, dynamic>> check(String userCode) async {
    final normalized = normalizeUserCode(userCode);
    final response = await _http
        .get(
          _baseUri
              .resolve('/device/verify')
              .replace(queryParameters: {'check': normalized}),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {'status': response.statusCode == 501 ? 'unavailable' : 'error'};
    }
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const {'status': 'error'};
    } catch (_) {
      return const {'status': 'error'};
    }
  }

  Future<http.Response> verify({
    required String accessToken,
    required String userCode,
    required bool approve,
  }) {
    return _http
        .post(
          _baseUri.resolve('/device/verify'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'user_code': normalizeUserCode(userCode),
            'approve': approve,
          }),
        )
        .timeout(requestTimeout);
  }
}
