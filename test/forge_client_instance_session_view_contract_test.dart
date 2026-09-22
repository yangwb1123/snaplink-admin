import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_CLIENT_INSTANCE_SESSION_VIEW_FIXTURE'];

  test(
    'consumes the shared Go/Rust client-instance/session-view fixture',
    () {
      final path = fixturePath;
      if (path == null || path.isEmpty) return;
      final source = File(path).readAsStringSync();
      final fixture = ForgeClientInstanceSessionView.fromJsonText(source);
      expect(fixture.schemaVersion, forgeClientInstanceSessionViewSchema);
      expect(
        fixture.evaluationMode,
        forgeClientInstanceSessionViewEvaluationMode,
      );
      expect(fixture.owner.subject, 'user-1');
      expect(fixture.owner.tenantID, 'tenant-1');
      expect(fixture.instances, hasLength(5));
      expect(fixture.instances.map((instance) => instance.clientKind), [
        'app',
        'cli',
        'mobile',
        'tui',
        'web',
      ]);
      expect(fixture.instances.last.status, 'idle');
      expect(fixture.authority.isOffline, isTrue);
      expect(fixture.isDisplayOnly, isTrue);
    },
    skip: fixturePath == null || fixturePath.isEmpty
        ? 'Run with the canonical Go/Rust fixture path.'
        : false,
  );

  test('round-trips only the strict metadata contract', () {
    final fixture = ForgeClientInstanceSessionView.fromJson(_fixture());
    expect(fixture.toJson(), _fixture());
    expect(fixture.isDisplayOnly, isTrue);
  });

  test('rejects unknown, null, enabled-authority, and trailing values', () {
    final unknown = _fixture();
    unknown['unexpected'] = true;
    expect(
      () => ForgeClientInstanceSessionView.fromJson(unknown),
      throwsA(isA<FormatException>()),
    );

    final nullStatus = _fixture();
    final nullStatusInstance = Map<String, dynamic>.from(
      (nullStatus['instances'] as List).first as Map,
    );
    nullStatusInstance['status'] = null;
    nullStatus['instances'] = [
      nullStatusInstance,
      ...(nullStatus['instances'] as List).skip(1),
    ];
    expect(
      () => ForgeClientInstanceSessionView.fromJson(nullStatus),
      throwsA(isA<FormatException>()),
    );

    final enabled = _fixture();
    (enabled['authority'] as Map<String, dynamic>)['dispatch_performed'] = true;
    expect(
      () => ForgeClientInstanceSessionView.fromJson(enabled),
      throwsA(isA<FormatException>()),
    );

    expect(
      () => ForgeClientInstanceSessionView.fromJsonText(
        '${jsonEncode(_fixture())}\n{}',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects duplicate JSON keys before Dart map decoding', () {
    final source = jsonEncode(_fixture());
    final duplicateRoot = source.replaceFirst(
      '"schema_version":"$forgeClientInstanceSessionViewSchema",',
      '"schema_version":"$forgeClientInstanceSessionViewSchema",'
          '"schema_version":"$forgeClientInstanceSessionViewSchema",',
    );
    expect(duplicateRoot, isNot(source));
    expect(
      () => ForgeClientInstanceSessionView.fromJsonText(duplicateRoot),
      throwsA(isA<FormatException>()),
    );

    final duplicateNested = source.replaceFirst(
      '"owner_authenticated":false,',
      '"owner_authenticated":false,"owner_authenticated":false,',
    );
    expect(duplicateNested, isNot(source));
    expect(
      () => ForgeClientInstanceSessionView.fromJsonText(duplicateNested),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unsupported kind/status and malformed owner metadata', () {
    final kind = _fixture();
    final kindInstance = Map<String, dynamic>.from(
      (kind['instances'] as List).first as Map,
    );
    kindInstance['client_kind'] = 'agent-hub';
    kind['instances'] = [kindInstance, ...(kind['instances'] as List).skip(1)];
    expect(
      () => ForgeClientInstanceSessionView.fromJson(kind),
      throwsA(isA<FormatException>()),
    );

    final status = _fixture();
    final statusInstance = Map<String, dynamic>.from(
      (status['instances'] as List).first as Map,
    );
    statusInstance['status'] = 'running';
    status['instances'] = [
      statusInstance,
      ...(status['instances'] as List).skip(1),
    ];
    expect(
      () => ForgeClientInstanceSessionView.fromJson(status),
      throwsA(isA<FormatException>()),
    );

    final owner = _fixture();
    (owner['owner_declaration'] as Map<String, dynamic>)['subject'] = ' ';
    expect(
      () => ForgeClientInstanceSessionView.fromJson(owner),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unsorted, duplicate, and out-of-bounds rows', () {
    final unsorted = _fixture();
    unsorted['instances'] = (unsorted['instances'] as List).reversed.toList();
    expect(
      () => ForgeClientInstanceSessionView.fromJson(unsorted),
      throwsA(isA<FormatException>()),
    );

    final duplicateInstance = _fixture();
    final rows = duplicateInstance['instances'] as List;
    duplicateInstance['instances'] = [rows.first, rows.first];
    expect(
      () => ForgeClientInstanceSessionView.fromJson(duplicateInstance),
      throwsA(isA<FormatException>()),
    );

    final duplicateSession = _fixture();
    final first = Map<String, dynamic>.from(
      (duplicateSession['instances'] as List).first as Map,
    );
    first['session_ids'] = ['conversation-001', 'conversation-001'];
    duplicateSession['instances'] = [
      first,
      ...(duplicateSession['instances'] as List).skip(1),
    ];
    expect(
      () => ForgeClientInstanceSessionView.fromJson(duplicateSession),
      throwsA(isA<FormatException>()),
    );

    final tooManyInstances = _fixture();
    tooManyInstances['instances'] = List.generate(
      forgeClientInstanceSessionViewMaxInstances + 1,
      (index) => {
        'instance_id': 'client-$index',
        'client_kind': 'cli',
        'session_ids': <String>[],
        'observed_at_ms': 200500,
        'status': 'active',
      },
    );
    expect(
      () => ForgeClientInstanceSessionView.fromJson(tooManyInstances),
      throwsA(isA<FormatException>()),
    );

    final tooManySessions = _fixture();
    final manySessions = Map<String, dynamic>.from(
      (tooManySessions['instances'] as List).first as Map,
    );
    manySessions['session_ids'] = List.generate(
      forgeClientInstanceSessionViewMaxSessionIDs + 1,
      (index) => 'conversation-${index.toString().padLeft(3, '0')}',
    );
    tooManySessions['instances'] = [
      manySessions,
      ...(tooManySessions['instances'] as List).skip(1),
    ];
    expect(
      () => ForgeClientInstanceSessionView.fromJson(tooManySessions),
      throwsA(isA<FormatException>()),
    );

    final unsafeTime = _fixture();
    final unsafeTimeInstance = Map<String, dynamic>.from(
      (unsafeTime['instances'] as List).first as Map,
    );
    unsafeTimeInstance['observed_at_ms'] =
        forgeClientInstanceSessionViewMaxSafeInteger + 1;
    unsafeTime['instances'] = [
      unsafeTimeInstance,
      ...(unsafeTime['instances'] as List).skip(1),
    ];
    expect(
      () => ForgeClientInstanceSessionView.fromJson(unsafeTime),
      throwsA(isA<FormatException>()),
    );

    expect(
      () => ForgeClientInstanceSessionView.fromJsonText(
        'x' * (2 * 1024 * 1024 + 1),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgeClientInstanceSessionViewSchema,
  'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
  'owner_declaration': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-cli-001',
      'client_kind': 'cli',
      'session_ids': ['conversation-001', 'conversation-002'],
      'observed_at_ms': 200500,
      'status': 'active',
    },
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': ['conversation-001'],
      'observed_at_ms': 200500,
      'status': 'idle',
    },
  ],
  'read_only': true,
  'authority': {
    'owner_authenticated': false,
    'session_read_authorized': false,
    'prompt_write_authorized': false,
    'device_identity_verified': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
