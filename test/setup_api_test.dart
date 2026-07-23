import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/setup/setup_api.dart';

void main() {
  test(
    'recognizes a disabled setup wizard without treating it as fresh',
    () async {
      final api = SetupApi(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/setup/status');
          return http.Response('{"error":"setup_disabled"}', 404);
        }),
      );

      final status = await api.checkStatus();

      expect(status.available, isFalse);
      expect(status.setupRequired, isFalse);
    },
  );

  test(
    'does not turn a failed setup-status probe into a create-admin flow',
    () async {
      final api = SetupApi(
        client: MockClient((_) async => http.Response('upstream error', 503)),
      );

      expect(api.checkStatus(), throwsA(isA<SetupNetworkError>()));
    },
  );
}
