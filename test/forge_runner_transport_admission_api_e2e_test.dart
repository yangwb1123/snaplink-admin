import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';

/// Opt-in integration entry for the accepted EXECUTE + P4 Runner transport
/// admission boundary. It consumes metadata only; the Console never opens a
/// Runner connection or sends payload bytes.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_RUNNER_TRANSPORT_ADMISSION_E2E_INPUT'];

  test(
    'Flutter consumes one authenticated Runner transport admission preview',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final requestValue = input['request'];
      if (requestValue is! Map) {
        throw const FormatException(
          'Missing Runner transport admission request.',
        );
      }
      final request = ForgeRunnerTransportAdmissionRequest.fromJson(
        requestValue,
      );
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final observation = await api.previewRunnerTransportAdmission(
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
        expect(observation.transportMethod, 'POST');
        expect(
          observation.transportPath,
          '/api/v1/runners/${request.command.leaseProof.targetID}/dispatch',
        );
        expect(
          observation.transportPayloadSHA256,
          request.transport.payloadSHA256,
        );
        expect(observation.admissionReady, isTrue);
        expect(observation.transportBindingValid, isTrue);
        expect(observation.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE + P4 Runner transport harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Runner transport admission E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Runner transport admission $key.');
  }
  return value;
}
