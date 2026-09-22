import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_local_runner_preview.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_terminal_receipt.dart';

/// Allows this opt-in test to reach the authenticated Forge candidate server.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_EXECUTION_READINESS_PROJECTION_E2E_INPUT'];

  test(
    'authenticated client instances consume resources before execution readiness preview',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final instanceID = _requiredText(input, 'instance_id');
      final conversationID = _requiredText(input, 'conversation_id');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final request = _request(owner);

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

        final observation = await api.previewLocalRunnerExecutionReadiness(
          conversationID: conversationID,
          intentID: 'intent-001',
          request: request,
        );
        expect(observation.runnerExecutionIntent.owner, owner);
        expect(observation.sessionRunnerReceipt.owner, owner);
        expect(observation.commandID, 'command-001');
        expect(observation.attemptID, 'attempt-001');
        expect(observation.targetID, 'runner-1');
        expect(observation.dispositionKind, 'completed');
        expect(observation.executorInvoked, isTrue);
        expect(observation.previewOnly, isTrue);
        expect(observation.exitCode, 0);
        expect(observation.authority.isOffline, isTrue);
        expect(observation.sessionRunnerReceipt.authority.isOffline, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the opt-in authenticated execution-readiness harness.'
        : false,
  );
}

ForgeLocalRunnerPreviewRequest _request(ForgeDeviceOwner owner) {
  final command = ForgeRunnerExecutionCommand(
    version: 1,
    commandID: 'command-001',
    leaseProof: const ForgeRunnerExecutionLeaseProof(
      attemptID: 'attempt-001',
      targetID: 'runner-1',
      epoch: 1,
      fencingToken: 'fence-001',
    ),
    idempotencyKey: 'run-001:attempt-001:command-001',
    workspaceRef: 'workspace-001',
    argv: const ['forge-task', '--prompt-ref', 'prompt-001'],
    timeoutMS: 5000,
    maxOutputBytes: 65536,
  );
  final intent = ForgeRunnerExecutionIntentRequest(
    owner: owner,
    conversationID: 'conversation-001',
    prompt: const ForgeRunnerExecutionPromptReceipt(
      promptID: 'prompt-001',
      conversationID: 'conversation-001',
      role: 'user',
      acceptedAtMS: 100,
      intentID: 'intent-001',
      initialEventID: 'event-001',
      initialEventSequence: 1,
      initialEventType: 'submitted',
      replayed: false,
    ),
    run: const ForgeRunnerExecutionRunReference(
      runID: 'run-001',
      conversationID: 'conversation-001',
      promptID: 'prompt-001',
      createdAtMS: 100,
      latestSequence: 1,
      status: 'nonterminal',
    ),
    binding: ForgeRunnerExecutionIntentBinding(
      conversationID: 'conversation-001',
      promptID: 'prompt-001',
      runID: 'run-001',
      attemptID: 'attempt-001',
      commandID: 'command-001',
      targetID: 'runner-1',
      commandSHA256: command.commandSHA256(),
      idempotencyKey: 'run-001:attempt-001:command-001',
      selectedTargetID: null,
    ),
    command: command,
  );
  return ForgeLocalRunnerPreviewRequest(
    intent: intent,
    grant: const ForgeRunnerTerminalReceiptGrant(
      version: 1,
      attemptID: 'attempt-001',
      targetID: 'runner-1',
      epoch: 1,
      fencingToken: 'fence-001',
      issuedAtMS: 100,
      expiresAtMS: 10100,
    ),
    observedAtMS: 300,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge client-instance execution-readiness input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException(
      'Missing Forge client-instance execution-readiness $key.',
    );
  }
  return value;
}
