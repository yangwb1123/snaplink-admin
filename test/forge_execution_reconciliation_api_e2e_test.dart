import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';

/// Opt-in integration entry for the accepted EXECUTE + P4 reconciliation
/// projection. The API receives a caller-supplied restart image and keeps the
/// result metadata-only; it never retries or authorizes the uncertain work.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_EXECUTION_RECONCILIATION_E2E_INPUT'];

  test(
    'Flutter consumes one authenticated execution reconciliation preview',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final requestValue = input['request'];
      if (requestValue is! Map) {
        throw const FormatException(
          'Missing execution reconciliation request.',
        );
      }
      final request = ForgeExecutionReconciliationInput.fromJson(requestValue);
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final observation = await api.previewExecutionReconciliation(
          conversationID: request.conversationID,
          runID: request.runID,
          input: request,
        );
        expect(observation.owner, request.owner);
        expect(observation.conversationID, request.conversationID);
        expect(observation.runID, request.runID);
        expect(observation.attemptID, request.attemptID);
        expect(observation.commandID, request.commandID);
        expect(observation.targetID, request.targetID);
        expect(observation.nextObservation, 'terminal_uncertain');
        expect(observation.reconciliationRequired, isTrue);
        expect(observation.manualReviewRequired, isTrue);
        expect(observation.automaticRetry, isFalse);
        expect(observation.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE reconciliation harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid execution reconciliation E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing execution reconciliation $key.');
  }
  return value;
}
