import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('domains_tab capabilities', () {
    test('detects availability', () {
      final caps = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/admin/domains', feature: 'core'),
      ]);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/domains'), isTrue);
    });
    test('documented routes are in catalog', () {
      expect(SnaplinkAdminOperationCatalog.endpoints.any((e) => e.path.contains('/domains')), isTrue);
    });
    test('returns false when absent', () {
      expect(SnaplinkAdminCapabilities([]).hasAnyPathPrefix('/api/v1/admin/domains'), isFalse);
    });
  });
}
