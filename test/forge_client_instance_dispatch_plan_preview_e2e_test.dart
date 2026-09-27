import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';

/// Allows this opt-in test to reach the authenticated Forge candidate server.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_DISPATCH_PLAN_PROJECTION_E2E_INPUT'];

  test(
    'authenticated client instances consume resources before dispatch preview',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final instanceID = _requiredText(input, 'instance_id');
      final conversationID = _requiredText(input, 'conversation_id');
      final runID = _requiredText(input, 'run_id');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final request = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
        input['request'],
      );
      if (request.owner != owner ||
          !request.isFor(conversationID, runID) ||
          request.dispatchPlan.placement.owner != owner) {
        throw const FormatException(
          'Dispatch-plan projection input has inconsistent owner or binding.',
        );
      }

      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
      );
      try {
        final convergence = await api.readConvergedClientInstanceViews(
          owner: owner,
        );
        final sessionView = convergence.sessionView;
        final resourceView = convergence.resourceView;
        final sessionInstance = sessionView.instances.singleWhere(
          (instance) => instance.instanceID == instanceID,
        );
        expect(resourceView.owner, owner);
        expect(sessionView.owner, owner);
        expect(resourceView.instances, hasLength(5));
        expect(sessionView.instances, hasLength(5));
        expect(resourceView.devices, hasLength(2));
        expect(sessionInstance.sessionIDs, contains(conversationID));
        final selectedInstance = resourceView.instances.singleWhere(
          (instance) => instance.instanceID == instanceID,
        );
        expect(selectedInstance.sessionIDs, contains(conversationID));
        expect(selectedInstance.toJson(), sessionInstance.toJson());
        expect(resourceView.devices.map((device) => device.deviceID), [
          'runner-1',
          'runner-2',
        ]);
        expect(resourceView.isDisplayOnly, isTrue);

        final preview = await api.previewRunnerDispatchPlan(
          owner: owner,
          conversationID: conversationID,
          runID: runID,
          dispatchPlan: request.dispatchPlan,
          candidateOrigin: apiURL,
        );
        expect(preview.owner, owner);
        expect(preview.isFor(conversationID, runID), isTrue);
        expect(preview.candidateCount, 2);
        expect(preview.declarativeReadyCount, 1);
        expect(preview.selectedTargetID, isNull);
        expect(preview.previewOnly, isTrue);
        expect(preview.reservationCreated, isFalse);
        expect(preview.executionAuthorized, isFalse);
        expect(preview.dispatchPerformed, isFalse);
        expect(
          preview.authority.values.every((value) => value == false),
          isTrue,
        );
        expect(preview.candidates.map((candidate) => candidate.targetID), [
          'runner-1',
          'runner-2',
        ]);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the opt-in authenticated dispatch projection harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge client-instance dispatch projection input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException(
      'Missing Forge client-instance dispatch projection $key.',
    );
  }
  return value;
}
