import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';
import 'package:sso_admin/screens/forge/forge_pending_run_intent_card.dart';

void main() {
  testWidgets('renders pending intent metadata without Prompt content', (
    tester,
  ) async {
    final fixture = ForgePendingRunIntentFixture.fromJson(_fixture());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ForgePendingRunIntentCard(fixture: fixture)),
      ),
    );

    expect(
      find.byKey(const ValueKey('forge-pending-run-intent-card')),
      findsOneWidget,
    );
    expect(find.text('Pending Run-intent preview'), findsOneWidget);
    expect(
      find.text('Receipt only. No Run was created and no device was selected.'),
      findsOneWidget,
    );
    expect(find.text('intent-001'), findsOneWidget);
    expect(find.text('prepare the report'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
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
