import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';

/// Allows this opt-in test to reach the authenticated Forge candidate.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_RUN_ATTEMPT_LEASE_DISPATCH_PREFLIGHT_E2E_INPUT'];

  test(
    'Flutter consumes authenticated Run/Attempt/lease preflight metadata',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final requestValue = input['request'];
      if (requestValue is! Map) {
        throw const FormatException(
          'Missing Forge Run/Attempt/lease preflight request.',
        );
      }
      final request = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
        requestValue,
      );
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        httpClient: http.Client(),
      );
      try {
        final observation = await api.previewRunAttemptLeaseDispatchPreflight(
          request: request,
        );

        expect(observation.issuer, request.owner.issuer);
        expect(observation.subject, request.owner.subject);
        expect(observation.tenantId, request.owner.tenantID);
        expect(observation.conversationId, request.conversationID);
        expect(observation.runId, request.runID);
        expect(observation.runStatus, request.runStatus);
        expect(
          observation.attemptId,
          request.dispatchPlan.runnerExecutionIntent.attemptID,
        );
        expect(observation.attemptState, request.dispatchPlan.attemptState);
        expect(
          observation.commandId,
          request.dispatchPlan.runnerExecutionIntent.commandID,
        );
        expect(
          observation.intentTargetId,
          request.dispatchPlan.runnerExecutionIntent.targetID,
        );
        expect(
          observation.leaseEpoch,
          request.dispatchPlan.lease.epoch.toInt(),
        );
        expect(
          observation.evaluatedAtMs,
          request.dispatchPlan.placement.evaluatedAtMS,
        );
        expect(
          observation.candidateCount,
          request.dispatchPlan.placement.devices.length,
        );
        expect(observation.selectedTargetId, isNull);
        expect(observation.previewOnly, isTrue);
        expect(observation.authority.values, everyElement(isFalse));
        expect(observation.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the opt-in authenticated preflight E2E harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge Run/Attempt/lease preflight E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Forge preflight $key.');
  }
  return value;
}
