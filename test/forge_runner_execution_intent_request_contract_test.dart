import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_RUNNER_EXECUTION_INTENT_REQUEST_FIXTURE'];

  test(
    'consumes the canonical Runner execution-intent request fixture',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final request = ForgeRunnerExecutionIntentRequest.fromJsonText(source);

      expect(request.conversationID, 'conversation-001');
      expect(request.prompt.promptID, 'prompt-001');
      expect(request.run.runID, 'run-001');
      expect(request.binding.targetID, 'runner-1');
      expect(request.binding.selectedTargetID, isNull);
      expect(request.binding.commandSHA256, request.command.commandSHA256());
      expect(request.toJson(), jsonDecode(source));
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects duplicate, unknown, selected-target, and digest drift',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final duplicate = source.replaceFirst(
        '  "owner": {',
        '  "owner": {},\n  "owner": {',
      );
      expect(
        () => ForgeRunnerExecutionIntentRequest.fromJsonText(duplicate),
        throwsFormatException,
      );

      final unknown = jsonDecode(source) as Map<String, dynamic>;
      unknown['unexpected'] = true;
      expect(
        () => ForgeRunnerExecutionIntentRequest.fromJson(unknown),
        throwsFormatException,
      );

      final selected = jsonDecode(source) as Map<String, dynamic>;
      (selected['execution_intent']
              as Map<String, dynamic>)['selected_target_id'] =
          'runner-1';
      expect(
        () => ForgeRunnerExecutionIntentRequest.fromJson(selected),
        throwsA(isA<ForgeRunnerExecutionIntentError>()),
      );

      final foreignRun = jsonDecode(source) as Map<String, dynamic>;
      (foreignRun['run_reference'] as Map<String, dynamic>)['run_id'] =
          'run-foreign';
      expect(
        () => ForgeRunnerExecutionIntentRequest.fromJson(foreignRun),
        throwsA(isA<ForgeRunnerExecutionIntentError>()),
      );

      final foreignPrompt = jsonDecode(source) as Map<String, dynamic>;
      (foreignPrompt['run_reference'] as Map<String, dynamic>)['prompt_id'] =
          'prompt-foreign';
      expect(
        () => ForgeRunnerExecutionIntentRequest.fromJson(foreignPrompt),
        throwsA(isA<ForgeRunnerExecutionIntentError>()),
      );

      final digest = jsonDecode(source) as Map<String, dynamic>;
      (digest['execution_intent'] as Map<String, dynamic>)['command_sha256'] =
          '0' * 64;
      expect(
        () => ForgeRunnerExecutionIntentRequest.fromJson(digest),
        throwsA(isA<ForgeRunnerExecutionIntentError>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}
