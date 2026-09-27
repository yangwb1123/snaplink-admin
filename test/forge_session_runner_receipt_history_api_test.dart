import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_history.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE'];

  test(
    'posts one authenticated canonical receipt-history preview',
    () async {
      final fixture = _fixture();
      final history = ForgeSessionRunnerReceiptHistory.fromJson(fixture);
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
            'runner-receipt-history/preview',
          );
          expect(request.url.query, isEmpty);
          expect(request.headers['authorization'], 'Bearer forge-bearer');
          return _json(fixture);
        }),
      );
      addTearDown(api.close);

      final returned = await api.previewSessionRunnerReceiptHistory(
        conversationID: 'conversation-001',
        runID: 'run-001',
        history: history,
      );

      expect(returned.isDisplayOnly, isTrue);
      expect(returned.isFor('conversation-001', 'run-001'), isTrue);
      expect(
        returned.receipts.map(
          (receipt) => receipt.receiptObservation.dispositionKind,
        ),
        ['failed', 'uncertain'],
      );
      expect(sent, hasLength(1));
      expect(jsonDecode(sent.single.body), history.toJson());
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects foreign or authority-bearing history responses',
    () async {
      final history = ForgeSessionRunnerReceiptHistory.fromJson(_fixture());
      final foreign = _fixture()..['run_id'] = 'run-foreign';
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((_) async => _json(foreign)),
      );
      addTearDown(api.close);

      await expectLater(
        api.previewSessionRunnerReceiptHistory(
          conversationID: 'conversation-001',
          runID: 'run-001',
          history: history,
        ),
        throwsA(isA<FormatException>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'does not refresh an unauthorized history preview',
    () async {
      final history = ForgeSessionRunnerReceiptHistory.fromJson(_fixture());
      var refreshes = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        refreshAccessToken: (_) async {
          refreshes++;
          return 'rotated-token';
        },
        httpClient: MockClient(
          (_) async => _json({
            'code': 'unauthorized',
            'message': 'expired',
          }, statusCode: 401),
        ),
      );
      addTearDown(api.close);

      await expectLater(
        api.previewSessionRunnerReceiptHistory(
          conversationID: 'conversation-001',
          runID: 'run-001',
          history: history,
        ),
        throwsA(isA<ForgeConversationsApiException>()),
      );
      expect(refreshes, 0);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

Map<String, dynamic> _fixture() {
  final path =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE'];
  if (path == null) throw StateError('fixture path is required');
  return Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
}

Response _json(Object body, {int statusCode = 200}) => Response(
  jsonEncode(body),
  statusCode,
  headers: const {'content-type': 'application/json'},
);
