import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_RUNNER_ATTEMPT_BOUNDARY_E2E_INPUT'];

  test(
    'shared Web App Mobile API consumes one authenticated Attempt boundary',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final request = ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(
        input['request'],
      );
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final observation = await api.previewRunnerAttemptBoundary(
          request: request,
          candidateOrigin: apiURL,
        );
        expect(observation.owner, request.owner);
        expect(observation.conversationID, request.conversationID);
        expect(observation.runID, request.runID);
        expect(observation.attemptID, request.attemptID);
        expect(observation.commandID, request.command.commandID);
        expect(observation.targetID, request.command.leaseProof.targetID);
        expect(observation.leaseEpoch, request.command.leaseProof.epoch);
        expect(observation.currentAttemptState, request.attemptState);
        expect(observation.transition, request.transition);
        expect(observation.attemptBoundaryReady, isTrue);
        expect(observation.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE + P4 Runner Attempt harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('Invalid Runner Attempt boundary E2E input.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Runner Attempt boundary $key.');
  }
  return value;
}
