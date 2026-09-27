import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_json_strict.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_terminal_receipt.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_RUNNER_TERMINAL_RECEIPT_VECTORS_FIXTURE'];

  test(
    'matches completed, failed, and uncertain Runner terminal receipt vectors',
    () {
      final source = File(fixturePath!).readAsStringSync();
      rejectDuplicateForgeJsonKeys(source);
      final root = _object(jsonDecode(source));
      _exactKeys(root, {
        'schema_version',
        'evaluation_mode',
        'authority',
        'vectors',
      });
      expect(
        root['schema_version'],
        'forge.runner-terminal-receipt-vectors/v1',
      );
      expect(
        root['evaluation_mode'],
        'pure_runner_terminal_receipt_vectors_only',
      );
      expect(
        ForgeRunnerTerminalReceiptAuthority.fromJson(
          root['authority'],
        ).isOffline,
        isTrue,
      );
      final vectors = root['vectors'];
      expect(vectors, isA<List<dynamic>>());
      expect(vectors, hasLength(3));
      for (final raw in vectors! as List<dynamic>) {
        final vector = _object(raw);
        _exactKeys(vector, {'name', 'grant', 'command', 'receipt', 'expected'});
        final command = _command(_object(vector['command']));
        final grant = ForgeRunnerTerminalReceiptGrant.fromJson(vector['grant']);
        final receipt = ForgeRunnerTerminalReceipt.fromJson(vector['receipt']);
        final expected = _object(vector['expected']);
        _exactKeys(expected, {
          'command_sha256',
          'disposition_kind',
          'receipt_valid',
          'uncertain',
          'reconciliation_required',
          'manual_review_required',
          'automatic_retry',
          'follow_up',
        });
        expect(command.commandSHA256(), expected['command_sha256']);
        expect(receipt.commandSHA256, expected['command_sha256']);
        final observation = observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: command,
            grant: grant,
            receipt: receipt,
          ),
        );
        expect(observation.dispositionKind, expected['disposition_kind']);
        expect(observation.receiptValid, expected['receipt_valid']);
        expect(observation.uncertain, expected['uncertain']);
        expect(
          observation.reconciliationRequired,
          expected['reconciliation_required'],
        );
        expect(
          observation.manualReviewRequired,
          expected['manual_review_required'],
        );
        expect(observation.automaticRetry, expected['automatic_retry']);
        expect(observation.followUp, expected['follow_up']);
        expect(observation.previewOnly, isTrue);
        expect(observation.authority.isOffline, isTrue);
      }
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects duplicate, unknown, trailing, digest, and expired vector values',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final duplicate = source.replaceFirst(
        '  "schema_version": "forge.runner-terminal-receipt-vectors/v1",',
        '  "schema_version": "forge.runner-terminal-receipt-vectors/v1",\n  "schema_version": "forge.runner-terminal-receipt-vectors/v1",',
      );
      expect(
        () => rejectDuplicateForgeJsonKeys(duplicate),
        throwsFormatException,
      );
      final unknown = _object(jsonDecode(source))..['unexpected'] = true;
      expect(() => _decodeStrict(jsonEncode(unknown)), throwsFormatException);
      expect(() => _decodeStrict('$source\n{}'), throwsFormatException);

      final root = _object(jsonDecode(source));
      final vectors = root['vectors'] as List<dynamic>;
      final first = _object(vectors.first);
      final request = _request(first);
      final digestDrift = ForgeRunnerTerminalReceipt(
        version: request.receipt.version,
        commandID: request.receipt.commandID,
        commandSHA256: 'b' * 64,
        proof: request.receipt.proof,
        disposition: request.receipt.disposition,
        observedAtMS: request.receipt.observedAtMS,
      );
      expect(
        () => observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: request.command,
            grant: request.grant,
            receipt: digestDrift,
          ),
        ),
        throwsA(isA<ForgeRunnerTerminalReceiptError>()),
      );
      final uncertain = _request(_object(vectors.last));
      final expiredGrant = ForgeRunnerTerminalReceiptGrant(
        version: uncertain.grant.version,
        attemptID: uncertain.grant.attemptID,
        targetID: uncertain.grant.targetID,
        epoch: uncertain.grant.epoch,
        fencingToken: uncertain.grant.fencingToken,
        issuedAtMS: uncertain.grant.issuedAtMS,
        expiresAtMS: uncertain.receipt.observedAtMS,
      );
      expect(
        () => observeForgeRunnerTerminalReceipt(
          ForgeRunnerTerminalReceiptRequest(
            command: uncertain.command,
            grant: expiredGrant,
            receipt: uncertain.receipt,
          ),
        ),
        throwsA(isA<ForgeRunnerTerminalReceiptError>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

ForgeRunnerTerminalReceiptRequest _request(Map<String, dynamic> vector) {
  return ForgeRunnerTerminalReceiptRequest(
    command: _command(_object(vector['command'])),
    grant: ForgeRunnerTerminalReceiptGrant.fromJson(vector['grant']),
    receipt: ForgeRunnerTerminalReceipt.fromJson(vector['receipt']),
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

Object _decodeStrict(String source) {
  rejectDuplicateForgeJsonKeys(source);
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected Runner terminal receipt vectors.');
  }
  _exactKeys(decoded, {
    'schema_version',
    'evaluation_mode',
    'authority',
    'vectors',
  });
  return decoded;
}
