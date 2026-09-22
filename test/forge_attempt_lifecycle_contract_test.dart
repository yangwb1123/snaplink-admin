import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_attempt_lifecycle.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_ATTEMPT_LIFECYCLE_FIXTURE'];

  test('consumes the shared Attempt lifecycle fixture as an offline value', () {
    if (fixturePath == null || fixturePath.isEmpty) {
      return;
    }
    final value = jsonDecode(File(fixturePath).readAsStringSync());
    final fixture = ForgeAttemptLifecycleFixture.fromJson(value);

    expect(fixture.schemaVersion, forgeAttemptLifecycleSchema);
    expect(fixture.evaluationMode, forgeAttemptLifecycleEvaluationMode);
    expect(fixture.authority.isOffline, isTrue);
    expect(jsonEncode(fixture.toJson()), jsonEncode(value));
    for (final edge in fixture.cases) {
      expect(
        ForgeAttemptLifecycleFixture.isTransitionAllowed(
          edge.fromState,
          edge.toState,
        ),
        edge.accepted,
      );
    }
  });

  test('fails closed on unknown fields and enabled authority', () {
    final value = _fixture();
    value['unexpected'] = true;
    expect(
      () => ForgeAttemptLifecycleFixture.fromJson(value),
      throwsA(isA<FormatException>()),
    );

    final authority = _fixture();
    (authority['authority'] as Map<String, dynamic>)['execution_authorized'] =
        true;
    expect(
      () => ForgeAttemptLifecycleFixture.fromJson(authority),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgeAttemptLifecycleSchema,
  'evaluation_mode': forgeAttemptLifecycleEvaluationMode,
  'authority': {
    'device_identity_verified': false,
    'command_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
  'cases': [
    {
      'name': 'requested_to_accepted',
      'from': 'requested',
      'to': 'accepted',
      'accepted': true,
    },
  ],
};
