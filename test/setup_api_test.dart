import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/setup_api.dart';

void main() {
  test('setup application preserves every redirect URI', () {
    const application = SetupApplication(
      name: 'Console',
      redirectUris: [
        'https://one.example/callback',
        'https://two.example/callback',
      ],
    );
    expect(application.toJson(), {
      'name': 'Console',
      'redirect_uris': [
        'https://one.example/callback',
        'https://two.example/callback',
      ],
    });
  });

  test(
    'successful setup can report admin without optional application',
    () async {
      final api = SetupApi(
        client: MockClient(
          (_) async => http.Response(
            '{"ok":true,"created":{"admin":"root"}}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final result = await api.submit(
        admin: const SetupAdmin(username: 'root', password: 'long-enough'),
        application: const SetupApplication(name: 'Requested app'),
      );

      expect(result.error, isNull);
      expect(result.createdAdmin, 'root');
      expect(result.clientId, isNull);
    },
  );

  test('setup failure retains description and trace reference', () async {
    final api = SetupApi(
      client: MockClient(
        (_) async => http.Response(
          '{"error":"invalid_request","error_description":"bad password",'
          '"trace_id":"trace-123"}',
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final result = await api.submit(
      admin: const SetupAdmin(username: 'root', password: 'long-enough'),
    );

    expect(result.error, contains('invalid_request'));
    expect(result.error, contains('bad password'));
    expect(result.error, contains('trace-123'));
  });

  test('maps a bounded setup timeout to a transport error', () async {
    var attempts = 0;
    final api = SetupApi(
      requestTimeout: const Duration(milliseconds: 5),
      client: MockClient((_) async {
        attempts++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      api.submit(
        admin: const SetupAdmin(username: 'root', password: 'safe'),
      ),
      throwsA(isA<SetupNetworkError>()),
    );
    expect(attempts, 1);
  });
}
