import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';

/// Opt-in integration entry for the accepted EXECUTE + P4 session receipt
/// projection. The Console verifies a caller-supplied, content-free receipt;
/// it never persists evidence, selects a target, or grants Runner authority.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_E2E_INPUT'];

  test(
    'Flutter consumes one authenticated session Runner receipt observation',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final observationValue = input['observation'];
      if (observationValue is! Map) {
        throw const FormatException(
          'Missing session Runner receipt observation.',
        );
      }
      final observation =
          ForgeSessionRunnerReceiptObservation.fromJson(observationValue);
      final conversationID = _requiredText(input, 'conversation_id');
      final promptID = _requiredText(input, 'prompt_id');
      final runID = _requiredText(input, 'run_id');
      if (!observation.isFor(conversationID, runID) ||
          observation.promptID != promptID) {
        throw const FormatException(
          'Session Runner receipt E2E binding is inconsistent.',
        );
      }
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final returned = await api.previewSessionRunnerReceiptObservation(
          conversationID: conversationID,
          runID: runID,
          observation: observation,
        );
        expect(returned.owner, observation.owner);
        expect(returned.promptID, promptID);
        expect(returned.receiptObservation.dispositionKind, 'completed');
        expect(returned.receiptObservation.receiptValid, isTrue);
        expect(returned.receiptObservation.uncertain, isFalse);
        expect(returned.receiptObservation.reconciliationRequired, isFalse);
        expect(returned.receiptObservation.manualReviewRequired, isFalse);
        expect(returned.receiptObservation.automaticRetry, isFalse);
        expect(returned.receiptObservation.followUp, 'none');
        expect(returned.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE session Runner receipt harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid session Runner receipt E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing session Runner receipt $key.');
  }
  return value;
}
