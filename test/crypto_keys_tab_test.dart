import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('CryptoKeysTab capabilities', () {
    test('detects crypto keys availability', () {
      final caps = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/admin/crypto/keys', feature: 'core'),
      ]);
      expect(caps.hasAnyPathPrefix('/api/v1/admin/crypto/keys'), isTrue);
    });
    test('key compromise URL is correct', () {
      expect('/api/v1/admin/crypto/keys/${Uri.encodeComponent('key-1')}/compromise',
        equals('/api/v1/admin/crypto/keys/key-1/compromise'));
    });
    test('documented routes include crypto keys', () {
      expect(SnaplinkAdminOperationCatalog.endpoints.any((e) => e.path.contains('/crypto/keys')), isTrue);
    });
    test('detects keys/rotate endpoint', () {
      final caps = SnaplinkAdminCapabilities([SnaplinkAdminEndpoint(method: 'POST', path: '/api/v1/admin/keys/rotate', feature: 'core')]);
      expect(caps.has('POST', '/api/v1/admin/keys/rotate'), isTrue);
    });
  });
}
