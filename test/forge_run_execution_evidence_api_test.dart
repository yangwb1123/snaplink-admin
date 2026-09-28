import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';

void main() {
  test(
    'posts one path-bound Run execution evidence pair',
    () async {
      final fixture = _fixture('FORGE_RUN_EXECUTION_EVIDENCE_CONTRACT_FIXTURE');
      final receiptFixture = _fixture(
        'FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE',
      );
      final run = ForgeRunObserved.fromJson(_runFromEvidence(fixture));
      final receipt = ForgeSessionRunnerReceiptObservation.fromJson(
        receiptFixture,
      );
      final sent = <Request>[];
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((request) async {
          sent.add(request);
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/conversations/conversation-001/runs/run-001/'
            'execution-evidence/preview',
          );
          expect(request.headers['authorization'], 'Bearer forge-bearer');
          return _json(fixture);
        }),
      );
      addTearDown(api.close);

      final returned = await api.previewRunExecutionEvidence(
        conversationID: 'conversation-001',
        runID: 'run-001',
        runObserved: run,
        sessionReceiptObserved: receipt,
      );

      expect(returned.isDisplayOnly, isTrue);
      expect(returned.ownerRef, run.ownerRef);
      expect(returned.promptID, 'prompt-001');
      expect(sent, hasLength(1));
      final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(body['run_observed'], run.toJson());
      expect(body['session_receipt_observed'], receipt.toJson());
    },
    skip:
        !_hasFixtures([
          'FORGE_RUN_EXECUTION_EVIDENCE_CONTRACT_FIXTURE',
          'FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE',
        ])
        ? 'Set the required Forge contract fixture paths.'
        : false,
  );

  test(
    'rejects Run execution evidence binding or authority drift',
    () async {
      final fixture = _fixture('FORGE_RUN_EXECUTION_EVIDENCE_CONTRACT_FIXTURE');
      final receipt = ForgeSessionRunnerReceiptObservation.fromJson(
        _fixture('FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE'),
      );
      final run = ForgeRunObserved.fromJson(_runFromEvidence(fixture));
      final foreign = Map<String, dynamic>.from(fixture);
      foreign['run_id'] = 'run-foreign';
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'token',
        httpClient: MockClient((_) async => _json(foreign)),
      );
      addTearDown(api.close);
      await expectLater(
        api.previewRunExecutionEvidence(
          conversationID: 'conversation-001',
          runID: 'run-001',
          runObserved: run,
          sessionReceiptObserved: receipt,
        ),
        throwsA(isA<FormatException>()),
      );
    },
    skip:
        !_hasFixtures([
          'FORGE_RUN_EXECUTION_EVIDENCE_CONTRACT_FIXTURE',
          'FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE',
        ])
        ? 'Set the required Forge contract fixture paths.'
        : false,
  );
}

bool _hasFixtures(List<String> variables) => variables.every(
  (variable) => Platform.environment[variable]?.isNotEmpty == true,
);

Map<String, dynamic> _fixture(String variable) {
  final path = Platform.environment[variable];
  if (path == null) throw StateError('$variable is required');
  return Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
}

Map<String, dynamic> _runFromEvidence(Map<String, dynamic> evidence) => {
  'api_version': 'forge.run.observed.v1',
  'owner_ref': evidence['owner_ref'],
  'conversation_id': evidence['conversation_id'],
  'run_id': evidence['run_id'],
  'prompt_id': evidence['prompt_id'],
  'created_at_ms': 200,
  'latest_sequence': 5,
  'status': evidence['run_status'],
  'metadata_observed': true,
  'content_included': false,
  'authority': {
    'identity_verified': false,
    'owner_authorized': false,
    'run_authoritative': false,
    'persistence_attested': false,
    'content_provenance_verified': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
  },
};

Response _json(Map<String, dynamic> body) => Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);
