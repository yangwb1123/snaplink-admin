import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_PENDING_RUN_INTENT_FIXTURE'];

  test(
    'consumes the shared pending Run-intent fixture as metadata',
    () {
      final path = fixturePath;
      if (path == null) return;
      final fixture = ForgePendingRunIntentFixture.fromJsonText(
        File(path).readAsStringSync(),
      );
      expect(fixture.schemaVersion, forgePendingRunIntentSchema);
      expect(fixture.evaluationMode, forgePendingRunIntentEvaluationMode);
      expect(fixture.authority.isOffline, isTrue);
      expect(fixture.conversationID, 'conversation-001');
      expect(fixture.submission.prompt.role, 'user');
      expect(fixture.submission.intent.status, 'pending');
      expect(fixture.timeline.event.type, 'submitted');
      expect(fixture.isDisplayOnly, isTrue);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects unknown fields, authority, bindings, and duplicate keys', () {
    final value = _fixture();
    value['unexpected'] = true;
    expect(
      () => ForgePendingRunIntentFixture.fromJson(value),
      throwsFormatException,
    );

    final authority = _fixture();
    (authority['authority'] as Map<String, dynamic>)['run_created'] = true;
    expect(
      () => ForgePendingRunIntentFixture.fromJson(authority),
      throwsFormatException,
    );

    final binding = _fixture();
    final submission = Map<String, dynamic>.from(binding['submission'] as Map);
    final intent = Map<String, dynamic>.from(submission['intent'] as Map);
    intent['conversation_id'] = 'conversation-other';
    submission['intent'] = intent;
    binding['submission'] = submission;
    expect(
      () => ForgePendingRunIntentFixture.fromJson(binding),
      throwsFormatException,
    );

    expect(
      () => ForgePendingRunIntentFixture.fromJsonText(
        '{"schema_version":"forge.pending-run-intent/v1",'
        '"schema_version":"forge.pending-run-intent/v1"}',
      ),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgePendingRunIntentSchema,
  'evaluation_mode': forgePendingRunIntentEvaluationMode,
  'authority': {
    'device_identity_verified': false,
    'inventory_authoritative': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'run_created': false,
    'audit_published': false,
  },
  'owner': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'conversation_id': 'conversation-001',
  'submission': {
    'prompt': {
      'id': 'prompt-001',
      'conversation_id': 'conversation-001',
      'role': 'user',
      'content': 'prepare the report',
      'created_at_ms': 200,
    },
    'intent': {
      'intent_id': 'intent-001',
      'conversation_id': 'conversation-001',
      'prompt_id': 'prompt-001',
      'project_id': 'project-001',
      'profile_id': 'profile-001',
      'submitted_at_ms': 200,
      'aggregate_version': 4,
      'latest_sequence': 1,
      'status': 'pending',
    },
    'initial_event': {
      'event_id': 'event-001',
      'seq': 1,
      'emitted_at_ms': 200,
      'type': 'submitted',
    },
    'replayed': false,
  },
  'page': {
    'conversation_id': 'conversation-001',
    'intents': [
      {
        'intent_id': 'intent-001',
        'conversation_id': 'conversation-001',
        'prompt_id': 'prompt-001',
        'project_id': 'project-001',
        'profile_id': 'profile-001',
        'submitted_at_ms': 200,
        'aggregate_version': 4,
        'latest_sequence': 1,
        'status': 'pending',
      },
    ],
    'next_cursor': null,
    'has_more': false,
  },
  'timeline': {
    'conversation_id': 'conversation-001',
    'intent_id': 'intent-001',
    'after_sequence': 0,
    'scanned_through_sequence': 1,
    'has_more': false,
    'events': [
      {
        'event_id': 'event-001',
        'seq': 1,
        'emitted_at_ms': 200,
        'type': 'submitted',
      },
    ],
  },
  'expected': {
    'prompt_role': 'user',
    'intent_status': 'pending',
    'initial_event_type': 'submitted',
    'timeline_event_count': 1,
    'replayed': false,
  },
};
