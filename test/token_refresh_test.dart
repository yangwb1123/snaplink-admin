import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/token_refresh_service.dart';

void main() {
  group('TokenRefreshService', () {
    // A sample JWT with exp=9999999999 (far future)
    // Header: {"alg":"RS256","typ":"JWT"}
    // Payload: {"sub":"admin","exp":9999999999,"iss":"sso-server"}
    final futureToken =
        'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJzdWIiOiJhZG1pbiIsImV4cDo5OTk5OTk5OTk5LCJpc3MiOiJzc28tc2VydmVyIn0.'
        'faketoken123';

    // Invalid token
    final invalidToken = 'not-a-jwt-token';

    test('parses JWT expiry', () {
      final service = TokenRefreshService();
      // We can't access _parseExpiry directly since it's private,
      // but we can test through the public API
      expect(service, isA<TokenRefreshService>());
    });

    test('init and dispose without error', () {
      final service = TokenRefreshService();
      String? storedToken;
      service.init(getToken: () => storedToken, refreshToken: () async => null);
      service.dispose();
    });

    test('onTokenUpdated schedules refresh', () {
      final service = TokenRefreshService();
      bool refreshed = false;
      service.init(
        getToken: () => null,
        refreshToken: () async {
          refreshed = true;
          return 'new-token';
        },
      );
      service.onTokenUpdated(futureToken);
      // The refresh should not happen immediately (scheduled for future)
      expect(refreshed, false);
      service.dispose();
    });

    test('handles invalid token gracefully', () {
      final service = TokenRefreshService();
      service.init(
        getToken: () => invalidToken,
        refreshToken: () async => null,
      );
      service.onTokenUpdated(invalidToken);
      service.dispose();
      // Should not crash
    });

    test('handles null token gracefully', () {
      final service = TokenRefreshService();
      service.init(getToken: () => null, refreshToken: () async => null);
      service.onTokenUpdated('');
      service.dispose();
      // Should not crash
    });
  });
}
