import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_terminal_receipt.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_RUNNER_TERMINAL_RECEIPT_CONTRACT_FIXTURE'];

  test(
    'consumes the strict Runner terminal receipt fixture read-only',
    () {
      final root = _object(jsonDecode(File(fixturePath!).readAsStringSync()));
      _exactKeys(root, {
        'schema_version',
        'evaluation_mode',
        'authority',
        'grant',
        'command',
        'receipt',
        'expected',
      });
      expect(root['schema_version'], forgeRunnerTerminalReceiptSchema);
      expect(root['evaluation_mode'], forgeRunnerTerminalReceiptEvaluationMode);
      expect(
        ForgeRunnerTerminalReceiptAuthority.fromJson(
          root['authority'],
        ).isOffline,
        isTrue,
      );

      final grant = ForgeRunnerTerminalReceiptGrant.fromJson(root['grant']);
      final command = _command(_object(root['command']));
      final receipt = ForgeRunnerTerminalReceipt.fromJson(root['receipt']);
      final expected = _object(root['expected']);
      _exactKeys(expected, {'command_sha256', 'receipt_valid'});
      expect(command.commandSHA256(), expected['command_sha256']);

      final observation = observeForgeRunnerTerminalReceipt(
        ForgeRunnerTerminalReceiptRequest(
          command: command,
          grant: grant,
          receipt: receipt,
        ),
      );
      expect(observation.schemaVersion, root['schema_version']);
      expect(observation.evaluationMode, root['evaluation_mode']);
      expect(observation.commandID, receipt.commandID);
      expect(observation.commandSHA256, expected['command_sha256']);
      expect(observation.attemptID, receipt.proof.attemptID);
      expect(observation.targetID, receipt.proof.targetID);
      expect(observation.observedAtMS, receipt.observedAtMS);
      expect(observation.previewOnly, isTrue);
      expect(observation.dispositionKind, 'completed');
      expect(observation.receiptValid, expected['receipt_valid']);
      expect(observation.uncertain, isFalse);
      expect(observation.reconciliationRequired, isFalse);
      expect(observation.manualReviewRequired, isFalse);
      expect(observation.automaticRetry, isFalse);
      expect(observation.followUp, 'none');
      expect(observation.authority.isOffline, isTrue);
      expect(
        ForgeRunnerTerminalReceiptObservation.fromJson(
          observation.toJson(),
        ).isDisplayOnly,
        isTrue,
      );
      final webIntegral = observation.toJson()
        ..['observed_at_ms'] = observation.observedAtMS.toDouble();
      expect(
        ForgeRunnerTerminalReceiptObservation.fromJson(
          webIntegral,
        ).observedAtMS,
        observation.observedAtMS,
      );
      final fractional = observation.toJson()..['observed_at_ms'] = 300.5;
      expect(
        () => ForgeRunnerTerminalReceiptObservation.fromJson(fractional),
        throwsA(isA<FormatException>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'uncertain is reconciliation/manual and never automatic retry',
    () {
      final root = _object(jsonDecode(File(fixturePath!).readAsStringSync()));
      final request = _request(root);
      final uncertain = ForgeRunnerTerminalReceipt(
        version: request.receipt.version,
        commandID: request.receipt.commandID,
        commandSHA256: request.receipt.commandSHA256,
        proof: request.receipt.proof,
        disposition: const ForgeRunnerTerminalReceiptDisposition.uncertain(
          'transport ended after effect boundary',
        ),
        observedAtMS: request.receipt.observedAtMS,
      );
      final observation = observeForgeRunnerTerminalReceipt(
        ForgeRunnerTerminalReceiptRequest(
          command: request.command,
          grant: request.grant,
          receipt: uncertain,
        ),
      );
      expect(observation.receiptValid, isTrue);
      expect(observation.uncertain, isTrue);
      expect(observation.reconciliationRequired, isTrue);
      expect(observation.manualReviewRequired, isTrue);
      expect(observation.followUp, 'reconciliation_manual');
      expect(observation.automaticRetry, isFalse);
      expect(observation.authority.isOffline, isTrue);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'fails closed on unknown fields, digest drift, foreign proof, and stale grant',
    () {
      final root = _object(jsonDecode(File(fixturePath!).readAsStringSync()));
      final request = _request(root);

      final receiptWithUnknown = _object(root['receipt'])
        ..['unexpected'] = true;
      expect(
        () => ForgeRunnerTerminalReceipt.fromJson(receiptWithUnknown),
        throwsA(isA<FormatException>()),
      );

      final grantWithUnknown = _object(root['grant'])..['unexpected'] = true;
      expect(
        () => ForgeRunnerTerminalReceiptGrant.fromJson(grantWithUnknown),
        throwsA(isA<FormatException>()),
      );

      final authorityWithGrant = _object(root['authority'])
        ..['execution_authorized'] = true;
      expect(
        () => ForgeRunnerTerminalReceiptAuthority.fromJson(authorityWithGrant),
        throwsA(isA<FormatException>()),
      );

      final digestDrift = _receipt(request.receipt, commandSHA256: 'b' * 64);
      expect(
        () => observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: request.command,
            grant: request.grant,
            receipt: digestDrift,
          ),
        ),
        throwsA(
          isA<ForgeRunnerTerminalReceiptError>().having(
            (error) => error.code,
            'code',
            'command_digest_mismatch',
          ),
        ),
      );

      final foreignProof = ForgeRunnerTerminalReceipt(
        version: request.receipt.version,
        commandID: request.receipt.commandID,
        commandSHA256: request.receipt.commandSHA256,
        proof: ForgeRunnerExecutionLeaseProof(
          attemptID: request.receipt.proof.attemptID,
          targetID: 'runner-foreign',
          epoch: request.receipt.proof.epoch,
          fencingToken: request.receipt.proof.fencingToken,
        ),
        disposition: request.receipt.disposition,
        observedAtMS: request.receipt.observedAtMS,
      );
      expect(
        () => observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: request.command,
            grant: request.grant,
            receipt: foreignProof,
          ),
        ),
        throwsA(
          isA<ForgeRunnerTerminalReceiptError>().having(
            (error) => error.code,
            'code',
            'proof_mismatch',
          ),
        ),
      );

      final staleGrant = ForgeRunnerTerminalReceiptGrant(
        version: request.grant.version,
        attemptID: request.grant.attemptID,
        targetID: request.grant.targetID,
        epoch: request.grant.epoch,
        fencingToken: request.grant.fencingToken,
        issuedAtMS: request.grant.issuedAtMS,
        expiresAtMS: request.receipt.observedAtMS,
      );
      expect(
        () => observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: request.command,
            grant: staleGrant,
            receipt: request.receipt,
          ),
        ),
        throwsA(isA<ForgeRunnerTerminalReceiptError>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects isolated UTF-16 surrogates before UTF-8 bounds are measured',
    () {
      final root = _object(jsonDecode(File(fixturePath!).readAsStringSync()));

      final commandWithIsolatedSurrogate = _object(root['command'])
        ..['command_id'] = '\uD800';
      final commandValue = _command(commandWithIsolatedSurrogate);
      final validRequest = _request(root);
      expect(
        () => observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: commandValue,
            grant: validRequest.grant,
            receipt: validRequest.receipt,
          ),
        ),
        throwsA(
          isA<ForgeRunnerTerminalReceiptError>().having(
            (error) => error.code,
            'code',
            'invalid_command',
          ),
        ),
      );

      final grantWithIsolatedSurrogate = _object(root['grant'])
        ..['fencing_token'] = '\uDFFF';
      final grant = ForgeRunnerTerminalReceiptGrant.fromJson(
        grantWithIsolatedSurrogate,
      );
      expect(
        () => observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: validRequest.command,
            grant: grant,
            receipt: validRequest.receipt,
          ),
        ),
        throwsA(
          isA<ForgeRunnerTerminalReceiptError>().having(
            (error) => error.code,
            'code',
            'invalid_grant',
          ),
        ),
      );

      final receiptWithIsolatedSurrogate = ForgeRunnerTerminalReceipt(
        version: validRequest.receipt.version,
        commandID: validRequest.receipt.commandID,
        commandSHA256: validRequest.receipt.commandSHA256,
        proof: validRequest.receipt.proof,
        disposition: const ForgeRunnerTerminalReceiptDisposition.uncertain(
          '\uD800',
        ),
        observedAtMS: validRequest.receipt.observedAtMS,
      );
      expect(
        () => observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: validRequest.command,
            grant: validRequest.grant,
            receipt: receiptWithIsolatedSurrogate,
          ),
        ),
        throwsA(
          isA<ForgeRunnerTerminalReceiptError>().having(
            (error) => error.code,
            'code',
            'invalid_disposition',
          ),
        ),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

ForgeRunnerTerminalReceiptRequest _request(Map<String, dynamic> root) {
  return ForgeRunnerTerminalReceiptRequest(
    command: _command(_object(root['command'])),
    grant: ForgeRunnerTerminalReceiptGrant.fromJson(root['grant']),
    receipt: ForgeRunnerTerminalReceipt.fromJson(root['receipt']),
  );
}

ForgeRunnerExecutionCommand _command(Map<String, dynamic> json) {
  _exactKeys(json, {
    'v',
    'command_id',
    'lease_proof',
    'idempotency_key',
    'workspace_ref',
    'argv',
    'timeout_ms',
    'max_output_bytes',
  });
  final proof = _object(json['lease_proof']);
  _exactKeys(proof, {'attempt_id', 'target_id', 'epoch', 'fencing_token'});
  final argv = json['argv'];
  if (argv is! List) throw const FormatException('Invalid Runner argv.');
  return ForgeRunnerExecutionCommand(
    version: _int(json['v']),
    commandID: _text(json['command_id']),
    leaseProof: ForgeRunnerExecutionLeaseProof(
      attemptID: _text(proof['attempt_id']),
      targetID: _text(proof['target_id']),
      epoch: _int(proof['epoch']),
      fencingToken: _text(proof['fencing_token']),
    ),
    idempotencyKey: _text(json['idempotency_key']),
    workspaceRef: _text(json['workspace_ref']),
    argv: argv.map(_text).toList(growable: false),
    timeoutMS: _int(json['timeout_ms']),
    maxOutputBytes: _int(json['max_output_bytes']),
  );
}

ForgeRunnerTerminalReceipt _receipt(
  ForgeRunnerTerminalReceipt receipt, {
  String? commandSHA256,
}) {
  return ForgeRunnerTerminalReceipt(
    version: receipt.version,
    commandID: receipt.commandID,
    commandSHA256: commandSHA256 ?? receipt.commandSHA256,
    proof: receipt.proof,
    disposition: receipt.disposition,
    observedAtMS: receipt.observedAtMS,
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw const FormatException('Expected object.');
  return Map<String, dynamic>.from(value);
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Runner fields.');
  }
}

String _text(Object? value) {
  if (value is! String) throw const FormatException('Expected text.');
  return value;
}

int _int(Object? value) {
  if (value is! int) throw const FormatException('Expected integer.');
  return value;
}
