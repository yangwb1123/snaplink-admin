import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_local_runner_preview.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_terminal_receipt.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';

/// Allows this opt-in test to reach the authenticated local Forge server.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_LOCAL_RUNNER_PREVIEW_E2E_INPUT'];

  test(
    'Flutter consumes the authenticated local Runner preview metadata',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner(
        issuer: _requiredText(input, 'issuer'),
        subject: _requiredText(input, 'subject'),
        tenantID: _requiredText(input, 'tenant_id'),
      );
      const conversationID = 'conversation-001';
      const intentID = 'intent-001';
      final request = _request(owner);

      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        httpClient: http.Client(),
      );
      try {
        final observation = await api.previewLocalRunnerExecutionReadiness(
          conversationID: conversationID,
          intentID: intentID,
          request: request,
        );

        // The URL path and every repeated identity must remain bound to the
        // caller's existing Conversation/Prompt/Run intent.
        final intent = observation.runnerExecutionIntent;
        final session = observation.sessionRunnerReceipt;
        final receipt = session.receiptObservation;
        expect(intent.owner, owner);
        expect(session.owner, owner);
        expect(intent.conversationID, conversationID);
        expect(session.conversationID, conversationID);
        expect(receipt.commandID, 'command-001');
        expect(receipt.attemptID, 'attempt-001');
        expect(receipt.targetID, 'runner-1');
        expect(intent.promptID, 'prompt-001');
        expect(session.promptID, 'prompt-001');
        expect(intent.runID, 'run-001');
        expect(session.runID, 'run-001');
        expect(observation.commandID, 'command-001');
        expect(observation.attemptID, 'attempt-001');
        expect(observation.targetID, 'runner-1');
        expect(observation.commandSHA256, request.intent.binding.commandSHA256);

        // This boundary reports only metadata from the injected executor.
        expect(intent.promptRunBindingValid, isTrue);
        expect(intent.runnerCommandBindingValid, isTrue);
        expect(intent.previewOnly, isTrue);
        expect(intent.selectedTargetID, isNull);
        expect(session.promptRunBindingValid, isTrue);
        expect(session.receiptBindingValid, isTrue);
        expect(session.previewOnly, isTrue);
        expect(session.selectedTargetID, isNull);
        expect(receipt.receiptValid, isTrue);
        expect(receipt.previewOnly, isTrue);
        expect(receipt.dispositionKind, 'completed');
        expect(receipt.observedAtMS, request.observedAtMS);
        expect(observation.dispositionKind, 'completed');
        expect(observation.observedAtMS, request.observedAtMS);
        expect(observation.executorInvoked, isTrue);
        expect(observation.previewOnly, isTrue);
        expect(observation.exitCode, 0);

        _expectRunnerIntentAuthorityOffline(intent.authority);
        _expectSessionAuthorityOffline(session.authority);
        _expectReceiptAuthorityOffline(receipt.authority);
        _expectPreviewAuthorityOffline(observation.authority);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the opt-in local Runner preview E2E harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge local Runner preview E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Forge local Runner preview $key.');
  }
  return value;
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

void _expectRunnerIntentAuthorityOffline(
  ForgeRunnerExecutionIntentAuthority authority,
) {
  expect(authority.deviceIdentityVerified, isFalse);
  expect(authority.commandPersisted, isFalse);
  expect(authority.reservationCreated, isFalse);
  expect(authority.executionAuthorized, isFalse);
  expect(authority.dispatchPerformed, isFalse);
  expect(authority.auditPublished, isFalse);
}

void _expectSessionAuthorityOffline(
  ForgeSessionRunnerReceiptObservationAuthority authority,
) {
  expect(authority.identityVerified, isFalse);
  expect(authority.receiptPersisted, isFalse);
  expect(authority.executionAuthorized, isFalse);
  expect(authority.dispatchPerformed, isFalse);
  expect(authority.auditPublished, isFalse);
}

void _expectReceiptAuthorityOffline(
  ForgeRunnerTerminalReceiptAuthority authority,
) {
  expect(authority.deviceIdentityVerified, isFalse);
  expect(authority.commandPersisted, isFalse);
  expect(authority.reservationCreated, isFalse);
  expect(authority.executionAuthorized, isFalse);
  expect(authority.dispatchPerformed, isFalse);
  expect(authority.auditPublished, isFalse);
}

void _expectPreviewAuthorityOffline(
  ForgeRunnerExecutionIntentAuthority authority,
) {
  _expectRunnerIntentAuthorityOffline(authority);
}
