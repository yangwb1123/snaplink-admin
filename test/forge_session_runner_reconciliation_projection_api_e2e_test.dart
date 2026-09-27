import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_history.dart';

/// Opt-in integration entry for the accepted EXECUTE + P4 reconciliation
/// projection. Core is contacted through two authenticated HTTP POSTs: the
/// history is canonicalized first and that response feeds the projection;
/// both responses remain bounded display values and never authorize retry.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_SESSION_RUNNER_RECONCILIATION_PROJECTION_E2E_INPUT'];

  test(
    'Flutter consumes the authenticated session Runner reconciliation chain',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final historyValue = input['history'];
      if (historyValue is! Map) {
        throw const FormatException(
          'Missing session Runner reconciliation history.',
        );
      }
      final history = ForgeSessionRunnerReceiptHistory.fromJson(historyValue);
      final conversationID = _requiredText(input, 'conversation_id');
      final promptID = _requiredText(input, 'prompt_id');
      final runID = _requiredText(input, 'run_id');
      if (!history.isDisplayOnly ||
          !history.hasUncertainTerminal ||
          !history.isFor(conversationID, runID) ||
          history.promptID != promptID) {
        throw const FormatException(
          'Session Runner reconciliation E2E history binding is invalid.',
        );
      }
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final projection = await api
            .previewSessionRunnerReconciliationFromHistory(
              conversationID: conversationID,
              runID: runID,
              history: history,
            );
        expect(projection.owner, history.owner);
        expect(projection.conversationID, conversationID);
        expect(projection.promptID, promptID);
        expect(projection.runID, runID);
        expect(projection.source.attemptCount, history.attemptCount);
        expect(projection.source.latestAttemptID, history.latestAttemptID);
        expect(projection.source.latestCommandID, history.latestCommandID);
        expect(projection.source.latestTargetID, history.latestTargetID);
        expect(
          projection.source.latestDispositionKind,
          history.latestDispositionKind,
        );
        expect(
          projection.source.latestObservedAtMS,
          history.latestObservedAtMS,
        );
        expect(projection.latestDispositionKind, 'uncertain');
        expect(projection.reconciliationKind, 'manual');
        expect(projection.reconciliationReason, 'uncertain_terminal_receipt');
        expect(projection.reconciliationRequired, isTrue);
        expect(projection.manualReviewRequired, isTrue);
        expect(projection.automaticRetry, isFalse);
        expect(projection.followUp, 'reconciliation_manual');
        expect(projection.selectedTargetID, isNull);
        expect(projection.previewOnly, isTrue);
        expect(projection.authority.isOffline, isTrue);
        expect(projection.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE session Runner reconciliation harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid session Runner reconciliation E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing session Runner reconciliation $key.');
  }
  return value;
}
