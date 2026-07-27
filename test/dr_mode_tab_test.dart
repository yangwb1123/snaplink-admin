import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('dr_mode_tab capabilities', () {
    test('detects availability', () {
      final caps = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/dr/mode',
          feature: 'core',
        ),
      ]);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/dr/mode'), isTrue);
    });
    test('documented routes are in catalog', () {
      final documented = SnaplinkAdminOperationCatalog.endpoints;
      expect(
        documented.any(
          (e) => e.method == 'GET' && e.path == '/api/v1/admin/dr/mode',
        ),
        isTrue,
      );
      expect(
        documented.any(
          (e) => e.method == 'POST' && e.path == '/api/v1/admin/dr/mode',
        ),
        isTrue,
      );
    });
    test('returns false when absent', () {
      expect(
        SnaplinkAdminCapabilities([]).hasAnyPathPrefix('/api/v1/admin/dr/mode'),
        isFalse,
      );
    });
  });
}
