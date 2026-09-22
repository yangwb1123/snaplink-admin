import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_credential_candidate.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

final _issueRequest = ForgeDeviceCredentialLifecycleRequest(
  deviceID: 'device-1',
  action: 'issue',
  approvalState: 'approved',
  credentialID: 'credential-1',
  keyID: 'key-1',
  publicKeySHA256: 'a' * 64,
  keyGeneration: 1,
  issuedAtMS: 100,
  expiresAtMS: 1100,
  nextCredentialID: '',
  nextKeyID: '',
  nextPublicKeySHA256: '',
  observedAtMS: 1000,
  expectedDeviceRevision: 7,
);

Map<String, dynamic> _candidate({ForgeDeviceOwner owner = _owner}) => {
  'schema_version': 'forge.device-credential-lifecycle/v1',
  'evaluation_mode': 'pure_device_credential_lifecycle',
  'owner': owner.toJson(),
  'device_id': 'device-1',
  'action': 'issue',
  'revision': 7,
  'next': {
    'credential_id': 'credential-1',
    'device_id': 'device-1',
    'owner': owner.toJson(),
    'approval_state': 'approved',
    'credential_state': 'active',
    'key_id': 'key-1',
    'public_key_sha256': 'a' * 64,
    'key_generation': 1,
    'issued_at_ms': 100,
    'expires_at_ms': 1100,
  },
  'preview_only': true,
  'candidate_published': true,
  'authority': {
    'owner_binding_matched': false,
    'owner_authenticated': false,
    'credential_material_made': false,
    'persisted': false,
    'inventory_authoritative': false,
    'execution_authorized': false,
  },
};

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  test('posts one strict owner-bound credential candidate', () async {
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'candidate-bearer',
      httpClient: MockClient((request) async {
        requests.add(request);
        return _json(_candidate());
      }),
    );
    addTearDown(api.close);

    final candidate = await api.previewDeviceCredentialCandidate(
      owner: _owner,
      request: _issueRequest,
      candidateOrigin: 'https://candidate.example',
    );

    expect(candidate.owner, _owner);
    expect(candidate.next.credentialID, 'credential-1');
    expect(candidate.isDisplayOnly, isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(
      requests.single.url.path,
      '/api/v1/device-enrollment-heartbeat/credential-candidate',
    );
    expect(requests.single.url.query, isEmpty);
    expect(jsonDecode(requests.single.body), _issueRequest.toJson());
    expect(requests.single.headers['authorization'], 'Bearer candidate-bearer');
    expect(requests.single.headers['cache-control'], 'no-store');
    expect(requests.single.headers.containsKey('idempotency-key'), isFalse);
  });

  test('candidate 401 is one-shot and never refreshes or replays', () async {
    var refreshes = 0;
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'expired-bearer',
      accessTokenProvider: () => 'expired-bearer',
      refreshAccessToken: (_) async {
        refreshes++;
        return 'rotated-bearer';
      },
      httpClient: MockClient((request) async {
        requests.add(request);
        return _json({
          'code': 'invalid_token',
          'message': 'expired',
        }, status: 401);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewDeviceCredentialCandidate(
        owner: _owner,
        request: _issueRequest,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsA(
        isA<ForgeConversationsApiException>()
            .having((error) => error.statusCode, 'status', 401)
            .having((error) => error.code, 'code', 'invalid_token'),
      ),
    );
    expect(requests, hasLength(1));
    expect(refreshes, 0);
  });

  test('rejects origin, owner, and response binding drift', () async {
    var requests = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'candidate-bearer',
      httpClient: MockClient((request) async {
        requests++;
        return _json(
          _candidate(
            owner: const ForgeDeviceOwner(
              issuer: 'https://id.example',
              subject: 'foreign-user',
              tenantID: 'tenant-1',
            ),
          ),
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewDeviceCredentialCandidate(
        owner: _owner,
        request: _issueRequest,
        candidateOrigin: 'https://other.example',
      ),
      throwsFormatException,
    );
    expect(requests, 0);

    await expectLater(
      api.previewDeviceCredentialCandidate(
        owner: _owner,
        request: _issueRequest,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
    expect(requests, 1);
  });

  test('rejects malformed requests before any network request', () async {
    var requests = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'candidate-bearer',
      httpClient: MockClient((_) async {
        requests++;
        return _json(_candidate());
      }),
    );
    addTearDown(api.close);

    final malformed = Map<String, dynamic>.from(_issueRequest.toJson())
      ..['credential_material'] = 'secret';
    expect(
      () => ForgeDeviceCredentialLifecycleRequest.fromJson(malformed),
      throwsFormatException,
    );
    expect(requests, 0);
  });
}
