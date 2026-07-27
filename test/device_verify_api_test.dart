import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/device/device_verify_api.dart';

void main() {
  test('normalizes human-entered user codes', () {
    expect(DeviceVerifyApi.normalizeUserCode(' wx-yz 1234 '), 'WXYZ-1234');
    expect(DeviceVerifyApi.normalizeUserCode('abcd'), 'ABCD');
    expect(DeviceVerifyApi.normalizeUserCode('abcd12345'), 'ABCD-1234');
  });

  test('checks device-code state before a decision', () async {
    final api = DeviceVerifyApi(
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/device/verify');
        expect(request.url.queryParameters['check'], 'WXYZ-1234');
        expect(request.headers['accept'], 'application/json');
        return http.Response('{"status":"pending"}', 200);
      }),
    );

    expect(await api.check('wxyz1234'), {'status': 'pending'});
  });

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

  test('times out a device decision without replaying it', () async {
    var attempts = 0;
    final api = DeviceVerifyApi(
      requestTimeout: const Duration(milliseconds: 5),
      httpClient: MockClient((_) async {
        attempts++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      api.verify(
        accessToken: 'user-token',
        userCode: 'WXYZ-1234',
        approve: false,
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(attempts, 1);
  });
}
