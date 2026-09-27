import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_runner_dispatch_admission.dart';

/// Opt-in integration entry for the accepted EXECUTE + P4 Runner admission
/// boundary. It consumes metadata only; the candidate never dispatches work.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_RUNNER_DISPATCH_ADMISSION_E2E_INPUT'];

  test(
    'Flutter consumes one authenticated Runner dispatch admission preview',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final requestValue = input['request'];
      if (requestValue is! Map) {
        throw const FormatException(
          'Missing Runner dispatch admission request.',
        );
      }
      final request = ForgeRunnerDispatchAdmissionRequest.fromJson(
        requestValue,
      );
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final observation = await api.previewRunnerDispatchAdmission(
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
        expect(observation.admissionReady, isTrue);
        expect(observation.leaseProofCurrent, isTrue);
        expect(observation.leaseActive, isTrue);
        expect(observation.commandBindingValid, isTrue);
        expect(observation.isDisplayOnly, isTrue);
        expect(observation.authority.deviceIdentityVerified, isFalse);
        expect(observation.authority.reservationCreated, isFalse);
        expect(observation.authority.executionAuthorized, isFalse);
        expect(observation.authority.dispatchPerformed, isFalse);
        expect(observation.authority.auditPublished, isFalse);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE + P4 Runner admission harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('Invalid Runner dispatch admission E2E input.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Runner dispatch admission $key.');
  }
  return value;
}
