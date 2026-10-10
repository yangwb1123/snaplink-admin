import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/session.dart';

void main() {
  tearDown(Session.clear);

  test(
    'core lists reject HTML/scalar success instead of returning empty data',
    () async {
      for (final payload in ['<html>private</html>', 'null', '[]', '42']) {
        var unauthorizedCalls = 0;
        final client = SSOAdminClient(
          'https://sso.example.test',
          onUnauthorized: () => unauthorizedCalls++,
          httpClient: MockClient((_) async => http.Response(payload, 200)),
        );
        Session.store('valid-fixture');
        await expectLater(
          client.listUsers(),
          throwsA(
            isA<SSOError>()
                .having((error) => error.error, 'code', 'invalid_response')
                .having(
                  (error) => error.toString(),
                  'no HTML',
                  isNot(contains('private')),
                ),
          ),
        );
        expect(unauthorizedCalls, 0);
        expect(Session.read(), 'valid-fixture');
      }
    },
  );

  test(
    'core transport parses nested configuration errors without a cast failure',
    () async {
      final client = SSOAdminClient(
        'https://sso.example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"error":{"code":"snaplink_invalid_upstream","message":"Check the Snaplink origin."}}',
            503,
          ),
        ),
      );
      await expectLater(
        client.listUsers(),
        throwsA(
          isA<SSOError>()
              .having((error) => error.status, 'status', 503)
              .having(
                (error) => error.error,
                'code',
                'snaplink_invalid_upstream',
              )
              .having(
                (error) => error.toString(),
                'message',
                'Check the Snaplink origin.',
              ),
        ),
      );
    },
  );
}
