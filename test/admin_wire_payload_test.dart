import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/admin_wire_payload.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';

import 'fixtures/admin_proto_fixture.dart';

void main() {
  test(
    'both admin transports accept real protojson pagination and records',
    () async {
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'nextPageToken': 'opaque/next',
            'totalSize': 42,
            'clients': [fixtureClient],
          }),
          200,
        );
      });
      final client = SSOAdminClient(
        'https://sso.example.test',
        httpClient: transport,
      );
      final page = await client.listClients(
        pageToken: 'opaque/previous',
        pageSize: 25,
      );
      expect(page.nextPageToken, 'opaque/next');
      expect(page.totalSize, 42);
      expect(page.items.single['redirect_uris'], fixtureClient['redirectUris']);
      expect(page.items.single['grant_types'], ['authorization_code']);
      expect(page.items.single['client_secret_expires_at'], '1900000000');
      expect(requests.single.url.queryParameters, {
        'page_token': 'opaque/previous',
        'page_size': '25',
      });
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'fixture',
        httpClient: transport,
      );
      final data = await api.get('/api/v1/admin/clients');
      expect(data['next_page_token'], 'opaque/next');
      expect(data['clients'].single['tenant_id'], 'tenant-1');
      transport.close();
    },
  );

  test('user and tenant adapters keep Struct keys and values opaque', () {
    final user = adminWirePayload('/api/v1/admin/users/user-1', {
      'user': fixtureUser,
    })['user'];
    expect(user['external_id'], 'external-1');
    expect(user['attributes'], fixtureUser['attributes']);
    expect(identical(user['attributes'], fixtureUser['attributes']), isTrue);
    expect(user['attributes'], isNot(contains('tenant_id')));
    final tenant = adminWirePayload('/api/v1/admin/tenants/tenant-1', {
      'tenant': fixtureTenant,
    })['tenant'];
    expect(tenant['home_region'], 'eu-west');
    expect(tenant['allowed_regions'], ['eu-west']);
    expect(tenant['enforce_writes'], isTrue);
    expect(tenant['settings'], fixtureTenant['settings']);
    expect(tenant['settings'], isNot(contains('home_region')));
  });

  for (final path in [
    '/api/v1/admin/users/user%2Fid',
    '/api/v1/admin/users/user%20id?view=full',
  ]) {
    test('opaque path identifiers do not disable the wire adapter: $path', () {
      expect(
        adminWirePayload(path, {'user': fixtureUser})['user']['external_id'],
        'external-1',
      );
    });
  }

  test('domain Get unwraps the published message envelope', () async {
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(protoResponses['/api/v1/admin/domains/example.test']),
          200,
        ),
      ),
    );
    final domain = await client.getDomain('example.test');
    expect(domain['hostname'], 'example.test');
    expect(domain['tenant_id'], 'tenant-1');
    expect(domain['is_apex'], isTrue);
  });

  test(
    'sessions, assignment roles and nested restore reports adapt known fields',
    () {
      final sessions = adminWirePayload(
        '/api/v1/admin/users/user-1/sessions',
        Map<String, dynamic>.from(
          protoResponses['/api/v1/admin/users/user-1/sessions']! as Map,
        ),
      );
      expect(sessions['sessions'].single['user_id'], 'user-1');
      expect(sessions['sessions'].single['created_at_unix'], '1700000000');
      final data = adminWirePayload('/api/v1/admin/snapshots:restore', {
        'report': {
          'operationId': 'operation-1',
          'safetySnapshotId': 'snapshot-1',
          'items': {
            'clients': {'inserted': 1, 'requiresRotation': 2},
          },
          'credentialRecovery': {'mfaReenrollmentRequired': 3},
        },
      });
      // snapshots:restore is the published colon-action RPC, not a child path.
      expect(data['report']['operation_id'], 'operation-1');
      expect(data['report']['safety_snapshot_id'], 'snapshot-1');
      expect(data['report']['items']['clients']['requires_rotation'], 2);
      expect(
        data['report']['credential_recovery']['mfa_reenrollment_required'],
        3,
      );
    },
  );

  test(
    'release references and durable operation progress keep quoted int64s',
    () {
      final release = adminWirePayload('/api/v1/admin/releases:current', {
        'release': fixtureRelease,
      })['release'];
      expect(release['released_at_unix'], '1700000000');
      expect(release['frontend']['git_ref'], 'frontend-ref');
      final data = adminWirePayload('/api/v1/admin/operations/operation-1', {
        'operation': {
          'currentStep': 'verify',
          'startedAtUnix': '1700000000',
          'steps': [
            {'updatedAtUnix': '1700000001'},
          ],
          'metadata': {'currentStep': 'opaque'},
          'resultJson': 'eyJwcml2YXRlIjoiZG9ub3RkZWNvZGUifQ==',
        },
      });
      expect(data['operation']['current_step'], 'verify');
      expect(data['operation']['started_at_unix'], '1700000000');
      expect(
        data['operation']['steps'].single['updated_at_unix'],
        '1700000001',
      );
      expect(data['operation']['metadata'], {'currentStep': 'opaque'});
      expect(
        data['operation']['result_json'],
        'eyJwcml2YXRlIjoiZG9ub3RkZWNvZGUifQ==',
      );
    },
  );

  for (final path in [
    '/api/v1/admin/users/user-1/mfa',
    '/api/v1/admin/users/user-1/devices',
    '/api/v1/admin/tenants/tenant-1/usage',
    '/api/v1/scim/v2/Users',
    '/api/v1/admin/commerce/plans',
    '/api/v1/audit/events',
    '/api/v1/admin/webhooks/subscriptions',
    '/api/v1/conversations',
    '/api/v1/admin/clients-preview',
  ]) {
    test('REST and independent service bodies remain untouched: $path', () {
      final payload = <String, dynamic>{
        'userId': 'opaque',
        'items': [
          {'tenantId': 'opaque'},
        ],
      };
      expect(identical(adminWirePayload(path, payload), payload), isTrue);
    });
  }

  test('legacy snake_case responses and original wire fields are retained', () {
    final payload = {
      'clients': [
        {
          'redirect_uris': ['https://legacy.test/cb'],
        },
      ],
      'next_page_token': 'next',
      'total_size': 2,
    };
    expect(adminWirePayload('/api/v1/admin/clients', payload), payload);
    final source = {'client': fixtureClient};
    final adapted = adminWirePayload('/api/v1/admin/clients/client-1', source);
    expect(adapted['client']['redirectUris'], fixtureClient['redirectUris']);
    expect(source, {'client': fixtureClient});
  });
}
