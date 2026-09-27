import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_history.dart';
import 'package:sso_admin/api/forge_session_runner_reconciliation_projection.dart';

void main() {
  final historyPath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE'];
  final projectionPath = Platform
      .environment['FORGE_SESSION_RUNNER_RECONCILIATION_PROJECTION_FIXTURE'];
  final skip = historyPath == null || projectionPath == null;

  test('posts one authenticated reconciliation projection preview', () async {
    final history = ForgeSessionRunnerReceiptHistory.fromJson(_history());
    final projection = ForgeSessionRunnerReconciliationProjection.fromJson(
      _projection(),
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
          'runner-reconciliation/preview',
        );
        expect(request.url.query, isEmpty);
        expect(request.headers['authorization'], 'Bearer forge-bearer');
        return _json(projection.toJson());
      }),
    );
    addTearDown(api.close);

    final returned = await api.previewSessionRunnerReconciliationProjection(
      conversationID: 'conversation-001',
      runID: 'run-001',
      history: history,
    );

    expect(returned.isDisplayOnly, isTrue);
    expect(returned.isFor('conversation-001', 'run-001'), isTrue);
    expect(returned.source.attemptCount, history.attemptCount);
    expect(sent, hasLength(1));
    expect(jsonDecode(sent.single.body), history.toJson());
  }, skip: skip);

  test(
    'canonicalizes history before deriving reconciliation projection',
    () async {
      final history = ForgeSessionRunnerReceiptHistory.fromJson(_history());
      final projection = ForgeSessionRunnerReconciliationProjection.fromJson(
        _projection(),
      );
      final sent = <Request>[];
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((request) async {
          sent.add(request);
          expect(request.method, 'POST');
          expect(request.url.query, isEmpty);
          expect(request.headers['authorization'], 'Bearer forge-bearer');
          if (sent.length == 1) {
            expect(
              request.url.path,
              '/api/v1/conversations/conversation-001/runs/run-001/'
              'runner-receipt-history/preview',
            );
            return _json(history.toJson());
          }
          expect(sent.length, 2);
          expect(
            request.url.path,
            '/api/v1/conversations/conversation-001/runs/run-001/'
            'runner-reconciliation/preview',
          );
          expect(jsonDecode(request.body), history.toJson());
          return _json(projection.toJson());
        }),
      );
      addTearDown(api.close);

      final returned = await api.previewSessionRunnerReconciliationFromHistory(
        conversationID: 'conversation-001',
        runID: 'run-001',
        history: history,
      );

      expect(returned.isDisplayOnly, isTrue);
      expect(returned.isFor('conversation-001', 'run-001'), isTrue);
      expect(returned.source.attemptCount, history.attemptCount);
      expect(sent, hasLength(2));
    },
    skip: skip,
  );

  test('rejects foreign or authority-bearing projection responses', () async {
    final history = ForgeSessionRunnerReceiptHistory.fromJson(_history());
    final foreign = _projection()..['run_id'] = 'run-foreign';
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async => _json(foreign)),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewSessionRunnerReconciliationProjection(
        conversationID: 'conversation-001',
        runID: 'run-001',
        history: history,
      ),
      throwsA(isA<FormatException>()),
    );

    final authority = _projection();
    authority['authority'] = Map<String, dynamic>.from(
      authority['authority'] as Map,
    )..['execution_authorized'] = true;
    final authorityApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async => _json(authority)),
    );
    addTearDown(authorityApi.close);
    await expectLater(
      authorityApi.previewSessionRunnerReconciliationProjection(
        conversationID: 'conversation-001',
        runID: 'run-001',
        history: history,
      ),
      throwsA(isA<FormatException>()),
    );
  }, skip: skip);

  test('does not refresh an unauthorized reconciliation preview', () async {
    final history = ForgeSessionRunnerReceiptHistory.fromJson(_history());
    var refreshes = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      refreshAccessToken: (_) async {
        refreshes++;
        return 'rotated-token';
      },
      httpClient: MockClient(
        (_) async => _json({'code': 'unauthorized'}, statusCode: 401),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewSessionRunnerReconciliationProjection(
        conversationID: 'conversation-001',
        runID: 'run-001',
        history: history,
      ),
      throwsA(isA<ForgeConversationsApiException>()),
    );
    expect(refreshes, 0);
  }, skip: skip);
}

Map<String, dynamic> _history() => Map<String, dynamic>.from(
  jsonDecode(
        File(
          Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE']!,
        ).readAsStringSync(),
      )
      as Map,
);

Map<String, dynamic> _projection() => Map<String, dynamic>.from(
  jsonDecode(
        File(
          Platform
              .environment['FORGE_SESSION_RUNNER_RECONCILIATION_PROJECTION_FIXTURE']!,
        ).readAsStringSync(),
      )
      as Map,
);

Response _json(Object body, {int statusCode = 200}) => Response(
  jsonEncode(body),
  statusCode,
  headers: const {'content-type': 'application/json'},
);
