import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';
import 'package:sso_admin/api/forge_runner_lease_fencing.dart';

/// Allows this opt-in test to reach the authenticated Forge candidate server.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_EXECUTION_RECONCILIATION_PROJECTION_E2E_INPUT'];

  test(
    'authenticated client instances reconcile a bound execution restart image',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final instanceID = _requiredText(input, 'instance_id');
      final conversationID = _requiredText(input, 'conversation_id');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final reconciliation = _reconciliationInput(owner);

      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
      );
      try {
        final resourceView = await api.readClientInstanceResourceViewCandidate(
          owner: owner,
        );
        expect(resourceView.owner, owner);
        expect(resourceView.instances, hasLength(5));
        expect(resourceView.devices, hasLength(2));
        final selectedInstance = resourceView.instances.singleWhere(
          (instance) => instance.instanceID == instanceID,
        );
        expect(selectedInstance.sessionIDs, contains(conversationID));
        expect(resourceView.devices.map((device) => device.deviceID), [
          'runner-1',
          'runner-2',
        ]);
        expect(resourceView.isDisplayOnly, isTrue);

        final observation = await api.previewExecutionReconciliation(
          conversationID: conversationID,
          runID: 'run-001',
          input: reconciliation,
        );
        expect(observation.owner, owner);
        expect(observation.conversationID, conversationID);
        expect(observation.runID, 'run-001');
        expect(observation.attemptID, 'attempt-001');
        expect(observation.commandID, 'command-001');
        expect(observation.targetID, 'runner-1');
        expect(observation.leaseEpoch, 1);
        expect(observation.leaseActive, isTrue);
        expect(observation.terminalObserved, isFalse);
        expect(observation.nextObservation, 'await_terminal');
        expect(observation.reconciliationRequired, isFalse);
        expect(observation.manualReviewRequired, isFalse);
        expect(observation.automaticRetry, isFalse);
        expect(observation.previewOnly, isTrue);
        expect(observation.authority.isOffline, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the opt-in authenticated execution-reconciliation harness.'
        : false,
  );
}

ForgeExecutionReconciliationInput _reconciliationInput(ForgeDeviceOwner owner) {
  final lease = ForgeRunnerLeaseGrant.issue(
    attemptID: 'attempt-001',
    targetID: 'runner-1',
    epoch: BigInt.one,
    fencingToken: 'fence-001',
    issuedAtMS: BigInt.from(100),
    ttlMS: BigInt.from(10000),
  );
  return ForgeExecutionReconciliationInput(
    owner: owner,
    conversationID: 'conversation-001',
    runID: 'run-001',
    attemptID: 'attempt-001',
    commandID: 'command-001',
    targetID: 'runner-1',
    runStatus: 'nonterminal',
    attemptState: 'running',
    lease: lease,
    observedAtMS: 300,
    terminal: null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge client-instance execution-reconciliation input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException(
      'Missing Forge client-instance execution-reconciliation $key.',
    );
  }
  return value;
}
