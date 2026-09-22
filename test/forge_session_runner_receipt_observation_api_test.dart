import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE'];

  test(
    'posts and strictly binds a session Runner receipt observation preview',
    () async {
      final fixture = _fixture();
      final observation = ForgeSessionRunnerReceiptObservation.fromJson(
        fixture,
      );
      late String requestBody;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((request) async {
          requestBody = request.body;
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/conversations/conversation-001/runs/run-001/'
            'runner-receipt-observation/preview',
          );
          expect(request.headers['authorization'], 'Bearer forge-bearer');
          return _jsonResponse(fixture);
        }),
      );
      addTearDown(api.close);

      final returned = await api.previewSessionRunnerReceiptObservation(
        conversationID: 'conversation-001',
        runID: 'run-001',
        observation: observation,
      );

      expect(returned.isDisplayOnly, isTrue);
      expect(returned.owner, observation.owner);
      expect(returned.promptID, 'prompt-001');
      expect(jsonEncode(jsonDecode(requestBody)), jsonEncode(fixture));
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects a preview response that changes the owner',
    () async {
      final fixture = _fixture();
      final observation = ForgeSessionRunnerReceiptObservation.fromJson(
        fixture,
      );
      final foreign = jsonDecode(jsonEncode(fixture)) as Map<String, dynamic>;
      (foreign['owner'] as Map<String, dynamic>)['subject'] = 'other-account';
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((_) async => _jsonResponse(foreign)),
      );
      addTearDown(api.close);

      await expectLater(
        api.previewSessionRunnerReceiptObservation(
          conversationID: observation.conversationID,
          runID: observation.runID,
          observation: observation,
        ),
        throwsA(isA<FormatException>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

Map<String, dynamic> _fixture() {
  final path =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE'];
  if (path == null) throw StateError('fixture path is required');
  return Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
}

Response _jsonResponse(Map<String, dynamic> body) => Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);
