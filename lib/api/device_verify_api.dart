import 'dart:convert';

import 'package:http/http.dart' as http;

/// Bearer-authenticated user leg of RFC 8628 device authorization.
class DeviceVerifyApi {
  final http.Client _http;

  DeviceVerifyApi({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Future<http.Response> verify({
    required String accessToken,
    required String userCode,
    required bool approve,
  }) {
    return _http.post(
      Uri.base.resolve('/device/verify'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'user_code': userCode, 'approve': approve}),
    );
  }
}
