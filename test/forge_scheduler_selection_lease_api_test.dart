import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';

void main() {
  test('posts one fenced scheduler lease with its idempotency key', () async {
    final request = _request();
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lease-token',
      httpClient: MockClient((http.Request incoming) async {
        expect(incoming.method, 'POST');
        expect(incoming.url.path, '/api/v1/device-placement/scheduler-lease');
        expect(incoming.headers['idempotency-key'], 'lease-key-00000001');
        expect(
          ForgeSchedulerSelectionLeaseRequest.fromJson(
            jsonDecode(incoming.body),
          ).toJson(),
          request.toJson(),
        );
        return http.Response(
          jsonEncode(_lease().toJson()),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    final lease = await api.claimSchedulerSelectionLease(
      request: request,
      idempotencyKey: 'lease-key-00000001',
      candidateOrigin: 'https://candidate.example/',
    );
    expect(lease.instanceID, 'runner-a');
    expect(lease.grant.epoch, 1);
    expect(lease.authority.executionAuthorized, isFalse);
  });

  test('rejects authority or binding drift', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lease-token',
      httpClient: MockClient((_) async {
        final root = _lease().toJson();
        (root['authority'] as Map<String, dynamic>)['execution_authorized'] =
            true;
        return http.Response(
          jsonEncode(root),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.claimSchedulerSelectionLease(
        request: _request(),
        idempotencyKey: 'lease-key-00000001',
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
  });

  test('renews one fenced scheduler lease with its idempotency key', () async {
    final request = _renewalRequest();
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lease-token',
      httpClient: MockClient((http.Request incoming) async {
        expect(incoming.method, 'POST');
        expect(
          incoming.url.path,
          '/api/v1/device-placement/scheduler-lease/renew',
        );
        expect(incoming.headers['idempotency-key'], 'renew-key-00000001');
        expect(
          ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(
            jsonDecode(incoming.body),
          ).toJson(),
          request.toJson(),
        );
        return http.Response(
          jsonEncode(_renewedLease().toJson()),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    final lease = await api.renewSchedulerSelectionLease(
      request: request,
      idempotencyKey: 'renew-key-00000001',
      candidateOrigin: 'https://candidate.example',
    );
    expect(lease.instanceID, 'runner-a');
    expect(lease.grant.epoch, 2);
    expect(lease.grant.fencingToken, 'token-b');
  });

  test('renewal rejects an unchanged epoch or target binding', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lease-token',
      httpClient: MockClient((_) async {
        final root = _lease().toJson();
        return http.Response(
          jsonEncode(root),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.renewSchedulerSelectionLease(
        request: _renewalRequest(),
        idempotencyKey: 'renew-key-00000001',
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
  });

  test('renewal rejects an epoch that skips a fencing step', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lease-token',
      httpClient: MockClient((_) async {
        final root = _renewedLease().toJson();
        (root['grant'] as Map<String, dynamic>)['epoch'] = 3;
        return http.Response(
          jsonEncode(root),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.renewSchedulerSelectionLease(
        request: _renewalRequest(),
        idempotencyKey: 'renew-key-00000001',
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
  });

  test(
    'releases one fenced scheduler lease with its idempotency key',
    () async {
      final request = _releaseRequest();
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'lease-token',
        httpClient: MockClient((http.Request incoming) async {
          expect(incoming.method, 'POST');
          expect(
            incoming.url.path,
            '/api/v1/device-placement/scheduler-lease/release',
          );
          expect(incoming.headers['idempotency-key'], 'release-key-00000001');
          expect(
            ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(
              jsonDecode(incoming.body),
            ).toJson(),
            request.toJson(),
          );
          return http.Response(
            jsonEncode(_release().toJson()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);
      final release = await api.releaseSchedulerSelectionLease(
        request: request,
        idempotencyKey: 'release-key-00000001',
        candidateOrigin: 'https://candidate.example',
      );
      expect(release.instanceID, 'runner-a');
      expect(release.epoch, 2);
      expect(release.authority.leaseIssued, isFalse);
    },
  );

  test('release rejects enabled authority or binding drift', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lease-token',
      httpClient: MockClient((_) async {
        final root = _release().toJson();
        (root['authority'] as Map<String, dynamic>)['lease_issued'] = true;
        return http.Response(
          jsonEncode(root),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.releaseSchedulerSelectionLease(
        request: _releaseRequest(),
        idempotencyKey: 'release-key-00000001',
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
  });

  test(
    'release surfaces a stale epoch without retrying or replaying',
    () async {
      var requests = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'lease-token',
        httpClient: MockClient((http.Request incoming) async {
          requests++;
          expect(incoming.method, 'POST');
          expect(
            incoming.url.path,
            '/api/v1/device-placement/scheduler-lease/release',
          );
          expect(incoming.headers['idempotency-key'], 'release-stale-00000001');
          return http.Response(
            jsonEncode({
              'code': 'lease_stale',
              'message': 'scheduler lease proof is stale',
            }),
            409,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);
      try {
        await api.releaseSchedulerSelectionLease(
          request: _releaseRequest(),
          idempotencyKey: 'release-stale-00000001',
          candidateOrigin: 'https://candidate.example',
        );
        fail('stale release unexpectedly succeeded');
      } on ForgeConversationsApiException catch (error) {
        expect(error.statusCode, 409);
        expect(error.code, 'lease_stale');
      }
      expect(requests, 1);
    },
  );

  test('strict decoder rejects duplicate and unknown fields', () {
    final encoded = jsonEncode(_lease().toJson());
    final duplicate = encoded.replaceFirst(
      '"schema_version":"${ForgeSchedulerSelectionLease.schema}",',
      '"schema_version":"${ForgeSchedulerSelectionLease.schema}","schema_version":"${ForgeSchedulerSelectionLease.schema}",',
    );
    expect(
      () => ForgeSchedulerSelectionLease.fromJsonText(duplicate),
      throwsFormatException,
    );
    final unknown = _lease().toJson()..['unexpected'] = true;
    expect(
      () => ForgeSchedulerSelectionLease.fromJson(unknown),
      throwsFormatException,
    );
  });
}

ForgeSchedulerSelectionLeaseRequest _request() =>
    ForgeSchedulerSelectionLeaseRequest(
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      requirements: const ForgeDevicePlacementRequirements(
        os: 'linux',
        architecture: 'amd64',
        minCPUCores: 1,
        minMemoryBytes: 1,
        minStorageBytes: 1,
        runtime: 'oci',
        gpu: ForgeDevicePlacementGpuRequirement(
          required: false,
          minMemoryBytes: 0,
          runtime: '',
        ),
        dataResidencyZones: ['us-west'],
        minimumTrustZone: 'standard',
        sandboxFloor: 'container',
        concurrencySlots: 1,
      ),
      ttlMS: 30000,
    );

ForgeSchedulerSelectionLeaseRenewalRequest _renewalRequest() =>
    const ForgeSchedulerSelectionLeaseRenewalRequest(
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      targetID: 'runner-a',
      epoch: 1,
      fencingToken: 'token-a',
      ttlMS: 30000,
    );

ForgeSchedulerSelectionLeaseReleaseRequest _releaseRequest() =>
    const ForgeSchedulerSelectionLeaseReleaseRequest(
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      targetID: 'runner-a',
      epoch: 2,
      fencingToken: 'token-b',
    );

ForgeSchedulerSelectionLease _lease() => const ForgeSchedulerSelectionLease(
  schemaVersion: ForgeSchedulerSelectionLease.schema,
  mode: ForgeSchedulerSelectionLease.evaluationMode,
  owner: ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-a',
    tenantID: 'tenant-a',
  ),
  conversationID: 'conversation-1',
  runID: 'run-1',
  attemptID: 'attempt-1',
  deviceID: 'device-a',
  instanceID: 'runner-a',
  inventoryRevision: 1,
  generation: 1,
  heartbeatSequence: 1,
  grant: ForgeExecutionLeaseGrant(
    version: 1,
    attemptID: 'attempt-1',
    targetID: 'runner-a',
    epoch: 1,
    fencingToken: 'token-a',
    issuedAtMS: 1800000000000,
    expiresAtMS: 1800000030000,
  ),
  replayed: false,
  authority: ForgeSchedulerSelectionLeaseAuthority(
    placementSelected: true,
    reservationCreated: true,
    leaseIssued: true,
    executionAuthorized: false,
    dispatchPerformed: false,
    auditPublished: false,
  ),
);

ForgeSchedulerSelectionLease _renewedLease() => ForgeSchedulerSelectionLease(
  schemaVersion: ForgeSchedulerSelectionLease.schema,
  mode: ForgeSchedulerSelectionLease.evaluationMode,
  owner: const ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-a',
    tenantID: 'tenant-a',
  ),
  conversationID: 'conversation-1',
  runID: 'run-1',
  attemptID: 'attempt-1',
  deviceID: 'device-a',
  instanceID: 'runner-a',
  inventoryRevision: 1,
  generation: 1,
  heartbeatSequence: 1,
  grant: const ForgeExecutionLeaseGrant(
    version: 1,
    attemptID: 'attempt-1',
    targetID: 'runner-a',
    epoch: 2,
    fencingToken: 'token-b',
    issuedAtMS: 1800000000000,
    expiresAtMS: 1800000030000,
  ),
  replayed: false,
  authority: const ForgeSchedulerSelectionLeaseAuthority(
    placementSelected: true,
    reservationCreated: true,
    leaseIssued: true,
    executionAuthorized: false,
    dispatchPerformed: false,
    auditPublished: false,
  ),
);

ForgeSchedulerSelectionLeaseRelease _release() =>
    const ForgeSchedulerSelectionLeaseRelease(
      schemaVersion: ForgeSchedulerSelectionLeaseRelease.schema,
      mode: ForgeSchedulerSelectionLeaseRelease.evaluationMode,
      owner: ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'user-a',
        tenantID: 'tenant-a',
      ),
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      deviceID: 'device-a',
      instanceID: 'runner-a',
      epoch: 2,
      releasedAtMS: 1800000010000,
      replayed: false,
      authority: ForgeSchedulerSelectionLeaseReleaseAuthority(
        placementSelected: false,
        reservationCreated: false,
        leaseIssued: false,
        executionAuthorized: false,
        dispatchPerformed: false,
        auditPublished: false,
      ),
    );
