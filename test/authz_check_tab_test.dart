import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('authz_check_tab capabilities', () {
    test('detects availability', () {
      final caps = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/rebac/check',
          feature: 'core',
        ),
      ]);
      expect(caps.has('GET', '/api/v1/admin/rebac/check'), isTrue);
    });
    test('documented routes are in catalog', () {
      expect(
        SnaplinkAdminOperationCatalog.endpoints.any(
          (e) => e.method == 'GET' && e.path == '/api/v1/admin/rebac/check',
        ),
        isTrue,
      );
    });
    test('returns false when absent', () {
      expect(
        SnaplinkAdminCapabilities([]).has('GET', '/api/v1/admin/rebac/check'),
        isFalse,
      );
    });
  });
}
