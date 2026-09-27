import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_json_strict.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_RUNNER_COMMAND_DIGEST_FIXTURE'];

  test(
    'matches the Go and Rust Runner command digest vectors',
    () {
      final source = File(fixturePath!).readAsStringSync();
      rejectDuplicateForgeJsonKeys(source);
      final root = jsonDecode(source);
      expect(root, isA<Map<String, dynamic>>());
      final envelope = root as Map<String, dynamic>;
      expect(envelope.keys.toSet(), {
        'schema_version',
        'digest_domain',
        'vectors',
      });
      expect(envelope['schema_version'], 'forge.runner-command-digest/v1');
      expect(envelope['digest_domain'], 'forge.runtime.runner-command.v1');
      final vectors = envelope['vectors'];
      expect(vectors, isA<List<dynamic>>());
      expect(vectors, hasLength(3));
      for (final raw in vectors! as List<dynamic>) {
        final vector = Map<String, dynamic>.from(raw as Map);
        expect(vector.keys.toSet(), {'name', 'command', 'command_sha256'});
        final command = ForgeRunnerExecutionCommand.fromJson(vector['command']);
        expect(command.commandSHA256(), vector['command_sha256']);
      }
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects duplicate, unknown, and trailing vector envelope values',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final duplicate = source.replaceFirst(
        '  "schema_version": "forge.runner-command-digest/v1",',
        '  "schema_version": "forge.runner-command-digest/v1",\n  "schema_version": "forge.runner-command-digest/v1",',
      );
      expect(
        () => rejectDuplicateForgeJsonKeys(duplicate),
        throwsFormatException,
      );

      final unknown = jsonDecode(source) as Map<String, dynamic>;
      unknown['unexpected'] = true;
      expect(() => _decodeStrict(jsonEncode(unknown)), throwsFormatException);

      expect(() => _decodeStrict(source), returnsNormally);
      expect(() => _decodeStrict('$source\n{}'), throwsFormatException);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

Object _decodeStrict(String source) {
  rejectDuplicateForgeJsonKeys(source);
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected command digest envelope.');
  }
  if (decoded.keys.length != 3 ||
      !decoded.keys.toSet().containsAll({
        'schema_version',
        'digest_domain',
        'vectors',
      })) {
    throw const FormatException('Unexpected command digest envelope field.');
  }
  return decoded;
}
