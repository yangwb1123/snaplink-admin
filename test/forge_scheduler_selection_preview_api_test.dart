import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';

void main() {
  test('posts one bound scheduler-selection preview without replay', () async {
    final request = _request();
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'scheduler-token',
      httpClient: MockClient((http.Request incoming) async {
        requests.add(incoming);
        expect(incoming.method, 'POST');
        expect(incoming.url.path, '/api/v1/device-placement/scheduler-preview');
        expect(incoming.url.query, isEmpty);
        expect(incoming.headers['authorization'], 'Bearer scheduler-token');
        final body = jsonDecode(incoming.body) as Map<String, dynamic>;
        expect(
          ForgeSchedulerSelectionPreviewRequest.fromJson(body).toJson(),
          request.toJson(),
        );
        return _json(_preview().toJson());
      }),
    );
    addTearDown(api.close);

    final preview = await api.previewSchedulerSelection(
      request: request,
      candidateOrigin: 'https://candidate.example/',
    );

    expect(requests, hasLength(1));
    expect(preview.selectedDeviceID, 'device-a');
    expect(preview.selectedInstanceID, 'runner-a');
    expect(preview.authority.anyGranted, isFalse);
  });

  test('rejects origin drift before issuing a request', () async {
    var count = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'scheduler-token',
      httpClient: MockClient((_) async {
        count++;
        return _json(_preview().toJson());
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewSchedulerSelection(
        request: _request(),
        candidateOrigin: 'https://other.example',
      ),
      throwsFormatException,
    );
    expect(count, 0);
  });

  test('rejects response binding and authority drift', () async {
    final mismatch = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'scheduler-token',
      httpClient: MockClient((_) async {
        final root = _preview().toJson()..['run_id'] = 'run-other';
        return _json(root);
      }),
    );
    addTearDown(mismatch.close);
    await expectLater(
      mismatch.previewSchedulerSelection(
        request: _request(),
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );

    final authority = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'scheduler-token',
      httpClient: MockClient((_) async {
        final root = _preview().toJson();
        (root['authority'] as Map<String, dynamic>)['lease_issued'] = true;
        return _json(root);
      }),
    );
    addTearDown(authority.close);
    await expectLater(
      authority.previewSchedulerSelection(
        request: _request(),
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
  });

  test('strict decoder rejects duplicate and unknown fields', () {
    final encoded = jsonEncode(_preview().toJson());
    final duplicate = encoded.replaceFirst(
      '"schema_version":"${ForgeSchedulerSelectionPreview.schema}",',
      '"schema_version":"${ForgeSchedulerSelectionPreview.schema}",'
          '"schema_version":"${ForgeSchedulerSelectionPreview.schema}",',
    );
    expect(
      () => ForgeSchedulerSelectionPreview.fromJsonText(duplicate),
      throwsFormatException,
    );
    final unknown = _preview().toJson()..['unexpected'] = true;
    expect(
      () => ForgeSchedulerSelectionPreview.fromJson(unknown),
      throwsFormatException,
    );
  });

  test('strict decoder accepts an empty selection only with its reason', () {
    final root = _preview().toJson()
      ..['selection_available'] = false
      ..['eligible_candidate_count'] = 0
      ..['selection_reason'] = 'no_eligible_candidate'
      ..['selected_device_id'] = null
      ..['selected_instance_id'] = null;
    expect(
      ForgeSchedulerSelectionPreview.fromJson(root).selectionAvailable,
      isFalse,
    );
    root['selection_reason'] = 'first_sorted_eligible_candidate';
    expect(
      () => ForgeSchedulerSelectionPreview.fromJson(root),
      throwsFormatException,
    );
  });
}

http.Response _json(Map<String, dynamic> value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

ForgeSchedulerSelectionPreviewRequest _request() =>
    ForgeSchedulerSelectionPreviewRequest(
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      requirements: _requirements(),
    );

ForgeDevicePlacementRequirements _requirements() =>
    const ForgeDevicePlacementRequirements(
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
    );

ForgeSchedulerSelectionPreview _preview() =>
    const ForgeSchedulerSelectionPreview(
      schemaVersion: ForgeSchedulerSelectionPreview.schema,
      mode: ForgeSchedulerSelectionPreview.evaluationMode,
      owner: ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'user-a',
        tenantID: 'tenant-a',
      ),
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      evaluatedAtMS: 1800000000000,
      candidateCount: 2,
      eligibleCandidateCount: 1,
      selectionAvailable: true,
      selectionReason: 'first_sorted_eligible_candidate',
      selectedDeviceID: 'device-a',
      selectedInstanceID: 'runner-a',
      previewOnly: true,
      authority: ForgeSchedulerSelectionAuthority(
        placementSelected: false,
        reservationCreated: false,
        leaseIssued: false,
        executionAuthorized: false,
        dispatchPerformed: false,
        auditPublished: false,
      ),
    );
