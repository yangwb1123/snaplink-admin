import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/device_security_models.dart';

void main() {
  group('DeviceBulkRevokeFilter', () {
    test('refuses to build an unbounded backend request', () {
      const filter = DeviceBulkRevokeFilter();

      expect(filter.hasCriteria, isFalse);
      expect(
        filter.matching([
          <String, dynamic>{'id': 'all'},
        ]),
        isEmpty,
      );
      expect(filter.toRequestBody, throwsStateError);
    });

    test('uses the same AND and strict-threshold semantics as Snaplink', () {
      const filter = DeviceBulkRevokeFilter(
        trustBelow: 0.4,
        suspiciousOnly: true,
        platform: 'Linux',
        deviceType: 'desktop',
      );
      final devices = [
        <String, dynamic>{
          'id': 'match',
          'trust_score': 0.39,
          'suspicious': true,
          'platform': 'Linux',
          'type': 'desktop',
        },
        <String, dynamic>{
          'id': 'equal-threshold',
          'trust_score': 0.4,
          'suspicious': true,
          'platform': 'Linux',
          'type': 'desktop',
        },
        <String, dynamic>{
          'id': 'wrong-platform',
          'trust_score': 0.1,
          'suspicious': true,
          'platform': 'Windows',
          'type': 'desktop',
        },
      ];

      expect(filter.toRequestBody(), {
        'trust_below': 0.4,
        'suspicious': true,
        'platform': 'Linux',
        'device_type': 'desktop',
      });
      expect(filter.matching(devices).map((item) => item['id']), ['match']);
      expect(filter.confirmationText(1), 'REVOKE 1 DEVICES');
    });

    test('a single supported condition is a valid bound', () {
      const filter = DeviceBulkRevokeFilter(suspiciousOnly: true);

      expect(filter.hasCriteria, isTrue);
      expect(filter.toRequestBody(), {'suspicious': true});
    });
  });

  test('builds encoded non-OpenAPI device routes', () {
    expect(deviceId({'device_id': 'from-event'}), 'from-event');
    expect(
      DeviceSecurityPaths.userDevice('user/a', 'device + 1'),
      '/api/v1/admin/users/user%2Fa/devices/device%20%2B%201',
    );
    expect(
      DeviceSecurityPaths.userLoginHistory('user/a'),
      '/api/v1/admin/users/user%2Fa/login-history',
    );
    expect(
      DeviceSecurityPaths.activity('device + 1'),
      '/api/v1/admin/devices/device%20%2B%201/activity',
    );
  });
}
