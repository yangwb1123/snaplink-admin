import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/portal/portal_api.dart';
import 'package:sso_admin/screens/portal/portal_security_contract.dart';

void main() {
  group('device response classification', () {
    test('builds the mounted physical-device subresource paths', () {
      expect(
        PortalSecurityPaths.device('phone / one'),
        '/me/devices/phone%20%2F%20one',
      );
      expect(
        PortalSecurityPaths.deviceActivity('device-1'),
        '/me/devices/device-1/activity',
      );
      expect(
        PortalSecurityPaths.deviceSessions('device-1'),
        '/me/devices/device-1/sessions',
      );
      expect(
        PortalSecurityPaths.deviceTrust('device-1'),
        '/me/devices/device-1/trust',
      );
      expect(
        PortalSecurityPaths.deviceLost('device-1'),
        '/me/devices/device-1/lost',
      );
      expect(
        PortalSecurityPaths.legacySession('session / one'),
        '/sessions/me/session%20%2F%20one',
      );
    });

    test('distinguishes physical devices from MFA trusted grants', () {
      final physical = <String, dynamic>{
        'id': 'device-1',
        'fingerprint': 'opaque-fingerprint',
        'platform': 'macOS',
        'device_name': 'Work Mac',
      };
      final grant = <String, dynamic>{
        'id': 'grant-1',
        'client_id': 'portal',
        'label': 'Chrome',
        'expires_at': '2026-08-01T00:00:00Z',
      };

      expect(isPhysicalDeviceRecord(physical), isTrue);
      expect(isTrustedDeviceGrant(physical), isFalse);
      expect(isPhysicalDeviceRecord(grant), isFalse);
      expect(isTrustedDeviceGrant(grant), isTrue);
      expect(
        classifyDeviceCollection([physical]),
        PortalDeviceCollectionKind.physical,
      );
      expect(
        classifyDeviceCollection([grant]),
        PortalDeviceCollectionKind.trustedGrants,
      );
      expect(
        classifyDeviceCollection([physical, grant]),
        PortalDeviceCollectionKind.ambiguous,
      );
    });

    test('does not classify an unknown record as a trusted grant', () {
      expect(isTrustedDeviceGrant({'id': 'unknown'}), isFalse);
      expect(
        classifyDeviceCollection([
          {'id': 'unknown'},
        ]),
        PortalDeviceCollectionKind.ambiguous,
      );
    });
  });

  group('enriched session loading', () {
    test('uses enriched sessions without probing the legacy route', () async {
      final paths = <String>[];
      final api = PortalApi(
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/me') return http.Response('{}', 200);
          if (request.url.path == '/me/sessions/enriched') {
            return http.Response(
              '{"sessions":[{"id":"s1","device_name":"Work Mac"}]}',
              200,
            );
          }
          return http.Response('', 500);
        }),
      );
      await api.login('token');

      final result = await loadPortalSessions(api);

      expect(result.usedLegacyEndpoint, isFalse);
      expect(result.sessions.single['device_name'], 'Work Mac');
      expect(paths, ['/me', '/me/sessions/enriched']);
    });

    for (final fallbackStatus in [404, 501]) {
      test('falls back only for $fallbackStatus from enriched route', () async {
        final paths = <String>[];
        final api = PortalApi(
          httpClient: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path == '/me') return http.Response('{}', 200);
            if (request.url.path == '/me/sessions/enriched') {
              return http.Response('', fallbackStatus);
            }
            if (request.url.path == '/sessions/me') {
              return http.Response('{"sessions":[{"id":"legacy"}]}', 200);
            }
            return http.Response('', 500);
          }),
        );
        await api.login('token');

        final result = await loadPortalSessions(api);

        expect(result.usedLegacyEndpoint, isTrue);
        expect(result.sessions.single['id'], 'legacy');
        expect(paths, ['/me', '/me/sessions/enriched', '/sessions/me']);
      });
    }

    test('does not hide an enriched endpoint server failure', () async {
      final paths = <String>[];
      final api = PortalApi(
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/me') return http.Response('{}', 200);
          return http.Response('', 500);
        }),
      );
      await api.login('token');

      await expectLater(
        loadPortalSessions(api),
        throwsA(
          isA<PortalApiError>().having((error) => error.status, 'status', 500),
        ),
      );
      expect(paths, ['/me', '/me/sessions/enriched']);
    });
  });
}
