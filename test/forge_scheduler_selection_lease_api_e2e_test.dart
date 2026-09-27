import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';

/// Uses the real authenticated Forge API. The same idempotency key is sent by
/// each independent Console client so the server returns the exact fenced
/// lease receipt rather than creating a second reservation.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_SCHEDULER_SELECTION_LEASE_E2E_INPUT'];

  test(
    'Console Web App and Mobile clients consume one accepted scheduler lease',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final clientKinds = _requiredTextList(input, 'client_kinds');
      final idempotencyKey = _requiredText(input, 'idempotency_key');
      final request = ForgeSchedulerSelectionLeaseRequest.fromJson(
        input['request'],
      );
      final expectedConversationID = _requiredText(
        input,
        'expected_conversation_id',
      );
      final expectedRunID = _requiredText(input, 'expected_run_id');
      final expectedAttemptID = _requiredText(input, 'expected_attempt_id');
      final expectedDeviceID = _requiredText(input, 'expected_device_id');
      final expectedInstanceID = _requiredText(input, 'expected_instance_id');
      if (request.conversationID != expectedConversationID ||
          request.runID != expectedRunID ||
          request.attemptID != expectedAttemptID) {
        throw const FormatException(
          'Scheduler lease input has inconsistent Run binding.',
        );
      }

      expect(clientKinds, ['web', 'app', 'mobile']);
      for (final clientKind in clientKinds) {
        final api = ForgeConversationsApi(
          baseUrl: apiURL,
          accessToken: accessToken,
          timeout: const Duration(seconds: 5),
        );
        try {
          final lease = await api.claimSchedulerSelectionLease(
            request: request,
            idempotencyKey: idempotencyKey,
            candidateOrigin: apiURL,
          );
          expect(lease.owner, owner, reason: clientKind);
          expect(
            lease.isFor(
              expectedConversationID,
              expectedRunID,
              expectedAttemptID,
            ),
            isTrue,
            reason: clientKind,
          );
          expect(lease.attemptID, expectedAttemptID, reason: clientKind);
          expect(lease.deviceID, expectedDeviceID, reason: clientKind);
          expect(lease.instanceID, expectedInstanceID, reason: clientKind);
          expect(lease.grant.targetID, expectedInstanceID, reason: clientKind);
          expect(lease.grant.attemptID, expectedAttemptID, reason: clientKind);
          expect(lease.authority.placementSelected, isTrue, reason: clientKind);
          expect(
            lease.authority.reservationCreated,
            isTrue,
            reason: clientKind,
          );
          expect(lease.authority.leaseIssued, isTrue, reason: clientKind);
          expect(
            lease.authority.executionAuthorized,
            isFalse,
            reason: clientKind,
          );
          expect(
            lease.authority.dispatchPerformed,
            isFalse,
            reason: clientKind,
          );
          expect(lease.authority.auditPublished, isFalse, reason: clientKind);
        } finally {
          api.close();
        }
      }
    },
    skip: inputPath == null || _inputHasKey(inputPath, 'renewal_request')
        ? 'Run through the accepted EXECUTE + P4 scheduler lease claim harness.'
        : false,
  );

  test(
    'Console Web App and Mobile clients replay one accepted lease renewal',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final clientKinds = _requiredTextList(input, 'client_kinds');
      final idempotencyKey = _requiredText(input, 'idempotency_key');
      final request = ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(
        input['renewal_request'],
      );
      final expectedDeviceID = _requiredText(input, 'expected_device_id');
      final expectedInstanceID = _requiredText(input, 'expected_instance_id');
      final expectedEpoch = _requiredInt(input, 'expected_epoch');

      expect(clientKinds, ['web', 'app', 'mobile']);
      for (final clientKind in clientKinds) {
        final api = ForgeConversationsApi(
          baseUrl: apiURL,
          accessToken: accessToken,
          timeout: const Duration(seconds: 5),
        );
        try {
          final lease = await api.renewSchedulerSelectionLease(
            request: request,
            idempotencyKey: idempotencyKey,
            candidateOrigin: apiURL,
          );
          expect(lease.owner, owner, reason: clientKind);
          expect(lease.replayed, isTrue, reason: clientKind);
          expect(lease.deviceID, expectedDeviceID, reason: clientKind);
          expect(lease.instanceID, expectedInstanceID, reason: clientKind);
          expect(lease.grant.targetID, request.targetID, reason: clientKind);
          expect(lease.grant.attemptID, request.attemptID, reason: clientKind);
          expect(lease.grant.epoch, expectedEpoch, reason: clientKind);
          expect(
            lease.authority.executionAuthorized,
            isFalse,
            reason: clientKind,
          );
          expect(
            lease.authority.dispatchPerformed,
            isFalse,
            reason: clientKind,
          );
          expect(lease.authority.auditPublished, isFalse, reason: clientKind);
        } finally {
          api.close();
        }
      }
    },
    skip: inputPath == null || !_inputHasKey(inputPath, 'renewal_request')
        ? 'Run through the accepted EXECUTE + P4 scheduler lease lifecycle harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge scheduler selection lease E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Forge scheduler lease E2E $key.');
  }
  return value;
}

List<String> _requiredTextList(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! List ||
      value.isEmpty ||
      value.any((item) => item is! String || item.isEmpty)) {
    throw FormatException('Missing Forge scheduler lease E2E $key.');
  }
  return value.cast<String>();
}

bool _inputHasKey(String? path, String key) {
  if (path == null) return false;
  final decoded = jsonDecode(File(path).readAsStringSync());
  return decoded is Map && decoded.containsKey(key);
}

int _requiredInt(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! int || value <= 0) {
    throw FormatException('Missing Forge scheduler lease E2E $key.');
  }
  return value;
}
