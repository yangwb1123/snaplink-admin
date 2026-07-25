import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('threat_policies_tab capabilities', () {
    test('detects availability', () {
      final caps = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/admin/threat-policies', feature: 'core'),
      ]);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/threat-policies'), isTrue);
    });
    test('documented routes are in catalog', () {
      expect(SnaplinkAdminOperationCatalog.endpoints.any((e) => e.path.contains('/threat_policies')), isTrue);
    });
    test('returns false when absent', () {
      expect(SnaplinkAdminCapabilities([]).hasAnyPathPrefix('/api/v1/admin/threat-policies'), isFalse);
    });
  });
}
