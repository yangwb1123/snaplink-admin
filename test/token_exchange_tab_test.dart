import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('token_exchange_tab capabilities', () {
    test('detects availability', () {
      final caps = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/admin/tokenexchange', feature: 'core'),
      ]);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/tokenexchange'), isTrue);
    });
    test('documented routes are in catalog', () {
      expect(SnaplinkAdminOperationCatalog.endpoints.any((e) => e.path.contains('/token_exchange')), isTrue);
    });
    test('returns false when absent', () {
      expect(SnaplinkAdminCapabilities([]).hasAnyPathPrefix('/api/v1/admin/tokenexchange'), isFalse);
    });
  });
}
