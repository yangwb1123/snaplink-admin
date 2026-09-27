import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';

/// Opt-in integration entry for the accepted EXECUTE + P4 Run evidence
/// projection. The Console sends only two already projected observations and
/// receives content-free binding metadata.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_RUN_EXECUTION_EVIDENCE_E2E_INPUT'];

  test(
    'Flutter consumes one authenticated Run execution evidence binding',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final runValue = input['run_observed'];
      final receiptValue = input['session_receipt_observed'];
      if (runValue is! Map || receiptValue is! Map) {
        throw const FormatException(
          'Missing Run execution evidence observations.',
        );
      }
      final run = ForgeRunObserved.fromJson(runValue);
      final receipt = ForgeSessionRunnerReceiptObservation.fromJson(
        receiptValue,
      );
      final conversationID = _requiredText(input, 'conversation_id');
      final runID = _requiredText(input, 'run_id');
      if (!run.isFor(conversationID, runID) ||
          !receipt.isFor(conversationID, runID) ||
          run.promptID != receipt.promptID) {
        throw const FormatException(
          'Run execution evidence E2E binding is inconsistent.',
        );
      }
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final returned = await api.previewRunExecutionEvidence(
          conversationID: conversationID,
          runID: runID,
          runObserved: run,
          sessionReceiptObserved: receipt,
        );
        expect(returned.ownerRef, run.ownerRef);
        expect(returned.promptID, run.promptID);
        expect(returned.runStatus, run.status);
        expect(
          returned.dispositionKind,
          receipt.receiptObservation.dispositionKind,
        );
        expect(returned.contentIncluded, isFalse);
        expect(returned.isDisplayOnly, isTrue);
        expect(returned.authority.isOffline, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE Run execution evidence harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('Invalid Run execution evidence E2E input.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Run execution evidence $key.');
  }
  return value;
}
