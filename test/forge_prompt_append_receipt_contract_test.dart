import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_prompt_append_receipt.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_PROMPT_APPEND_RECEIPT_FIXTURE'];

  test(
    'consumes canonical Prompt append request/receipt fixture',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final observation = ForgePromptAppendReceiptObservation.fromJsonText(
        source,
      );
      expect(observation.request.conversationID, 'conversation-001');
      expect(observation.request.expectedVersion, 2);
      expect(observation.receipt.promptID, 'prompt-003');
      expect(observation.receipt.aggregateVersion, 3);
      expect(observation.receipt.contentIncluded, isFalse);
      expect(observation.isDisplayOnly, isTrue);
      expect(
        observation.toJson(),
        equals(jsonDecode(source) as Map<String, dynamic>),
      );
      final recomputed = ForgePromptAppendReceiptObservation.fromInput(
        owner: observation.owner,
        conversationID: 'conversation-001',
        expectedVersion: 2,
        content: 'send this from another client',
        idempotencyKey: 'prompt-key-003',
        promptID: 'prompt-003',
        createdAtMS: 300,
        replayed: false,
      );
      expect(recomputed.toJson(), equals(observation.toJson()));
    },
    skip: fixturePath == null,
  );

  test('fails closed on wire, binding, and downstream authority drift', () {
    final unknown = _fixture()..['unexpected'] = true;
    expect(
      () => ForgePromptAppendReceiptObservation.fromJson(unknown),
      throwsFormatException,
    );
    final duplicate = jsonEncode(_fixture()).replaceFirst(
      '"schema_version":"$forgePromptAppendReceiptSchema",',
      '"schema_version":"$forgePromptAppendReceiptSchema",'
          '"schema_version":"$forgePromptAppendReceiptSchema",',
    );
    expect(
      () => ForgePromptAppendReceiptObservation.fromJsonText(duplicate),
      throwsFormatException,
    );
    expect(
      () => ForgePromptAppendReceiptObservation.fromJsonText(
        '${jsonEncode(_fixture())} {}',
      ),
      throwsFormatException,
    );
    final version = _fixture();
    (version['receipt'] as Map<String, dynamic>)['aggregate_version'] = 4;
    expect(
      () => ForgePromptAppendReceiptObservation.fromJson(version),
      throwsFormatException,
    );
    final authority = _fixture();
    (authority['authority'] as Map<String, dynamic>)['audit_published'] = true;
    expect(
      () => ForgePromptAppendReceiptObservation.fromJson(authority),
      throwsFormatException,
    );
    final content = _fixture();
    (content['receipt'] as Map<String, dynamic>)['content_included'] = true;
    expect(
      () => ForgePromptAppendReceiptObservation.fromJson(content),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgePromptAppendReceiptSchema,
  'owner': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'request': {
    'conversation_id': 'conversation-001',
    'expected_version': 2,
    'role': 'user',
    'content_sha256':
        'ba7c92f7b6cf793207184c5eeb0faf9d07f20f822122a3496981848a16237477',
    'idempotency_key_sha256':
        '28000a1da51a81095e5dcd089338c3884c551a2538343d090e6459542dc1f3b9',
  },
  'receipt': {
    'conversation_id': 'conversation-001',
    'prompt_id': 'prompt-003',
    'role': 'user',
    'aggregate_version': 3,
    'created_at_ms': 300,
    'replayed': false,
    'storage_commit_observed': true,
    'content_included': false,
  },
  'authority': {
    'run_created': false,
    'device_selected': false,
    'reservation_created': false,
    'dispatch_performed': false,
    'execution_authorized': false,
    'audit_published': false,
  },
};
