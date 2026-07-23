import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/device/device_verify_api.dart';

void main() {
  test('approves a device code with the current bearer', () async {
    final api = DeviceVerifyApi(
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/device/verify');
        expect(request.headers['authorization'], 'Bearer user-token');
        expect(jsonDecode(request.body), {
          'user_code': 'WXYZ-1234',
          'approve': true,
        });
        return http.Response('{}', 200);
      }),
    );

    final response = await api.verify(
      accessToken: 'user-token',
      userCode: 'WXYZ-1234',
      approve: true,
    );

    expect(response.statusCode, 200);
  });
}
