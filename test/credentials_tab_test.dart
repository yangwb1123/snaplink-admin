import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('credentials_tab capabilities', () {
    test('detects availability', () {
      final caps = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/admin/credentials', feature: 'core'),
      ]);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/credentials'), isTrue);
    });
    test('documented routes are in catalog', () {
      expect(SnaplinkAdminOperationCatalog.endpoints.any((e) => e.path.contains('/credentials')), isTrue);
    });
    test('returns false when absent', () {
      expect(SnaplinkAdminCapabilities([]).hasAnyPathPrefix('/api/v1/admin/credentials'), isFalse);
    });
  });
}
