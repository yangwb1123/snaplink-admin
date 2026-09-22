import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_run_observed.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_RUN_OBSERVED_FIXTURE'];

  test(
    'consumes the shared content-free Run observer fixture',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final fixture = _object(jsonDecode(source));
      final observed = ForgeRunObserved.fromJsonText(source);
      expect(
        observed.ownerRef,
        '21444e9222fa722f4b05e8a353e2e840594863c941bba4c2222b3c22bb198ba5',
      );
      expect(observed.conversationID, 'conversation-001');
      expect(observed.runID, 'run-001');
      expect(observed.promptID, 'prompt-001');
      expect(observed.latestSequence, 5);
      expect(observed.status, 'nonterminal');
      expect(observed.metadataObserved, isTrue);
      expect(observed.contentIncluded, isFalse);
      expect(observed.authority.isAllFalse, isTrue);
      expect(jsonEncode(observed.toJson()), jsonEncode(fixture));
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects unknown fields, content and authority claims', () {
    final fixture = _fixture();
    expect(
      () => ForgeRunObserved.fromJson({...fixture, 'unexpected': true}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeRunObserved.fromJson({...fixture, 'prompt': 'secret'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeRunObserved.fromJson({...fixture, 'content_included': true}),
      throwsA(isA<FormatException>()),
    );
    final authority = Map<String, dynamic>.from(fixture['authority'] as Map)
      ..['execution_authorized'] = true;
    expect(
      () => ForgeRunObserved.fromJson({...fixture, 'authority': authority}),
      throwsA(isA<FormatException>()),
    );
  });

  test('raw decoding rejects root and nested duplicate keys', () {
    final source = jsonEncode(_fixture());
    final rootDuplicate = source.replaceFirst(
      '"api_version":"$forgeRunObservedSchema"',
      '"api_version":"$forgeRunObservedSchema","api_version":"$forgeRunObservedSchema"',
    );
    expect(
      () => ForgeRunObserved.fromJsonText(rootDuplicate),
      throwsA(isA<FormatException>()),
    );

    final nestedDuplicate = source.replaceFirst(
      '"identity_verified":false',
      '"identity_verified":false,"identity_verified":false',
    );
    expect(
      () => ForgeRunObserved.fromJsonText(nestedDuplicate),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _fixture() => {
  'api_version': forgeRunObservedSchema,
  'owner_ref':
      '21444e9222fa722f4b05e8a353e2e840594863c941bba4c2222b3c22bb198ba5',
  'conversation_id': 'conversation-001',
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'created_at_ms': 200,
  'latest_sequence': 5,
  'status': 'nonterminal',
  'metadata_observed': true,
  'content_included': false,
  'authority': {
    'identity_verified': false,
    'owner_authorized': false,
    'run_authoritative': false,
    'persistence_attested': false,
    'content_provenance_verified': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
  },
};

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw const FormatException('Expected fixture object.');
  return Map<String, dynamic>.from(value);
}
