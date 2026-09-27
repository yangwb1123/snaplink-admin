import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';

void main() {
  test('parses the canonical metadata-only transport admission fixture', () {
    final path =
        Platform.environment['FORGE_RUNNER_TRANSPORT_ADMISSION_FIXTURE'];
    if (path == null || path.isEmpty) {
      return;
    }
    final source = File(path).readAsStringSync();
    final parsed = ForgeRunnerTransportAdmission.fromJsonText(source);
    expect(ForgeRunnerTransportAdmission.schema, isNotEmpty);
    expect(parsed.isDisplayOnly, isTrue);
    expect(parsed.admissionReady, isTrue);
    expect(parsed.transportMethod, 'POST');
    expect(parsed.transportPath, '/api/v1/runners/${parsed.targetID}/dispatch');
    expect(parsed.rejectionReasons, isEmpty);
    expect(jsonEncode(parsed.toJson()), isNot(contains('fencing_token')));
    expect(jsonEncode(parsed.toJson()), isNot(contains('argv')));
    expect(jsonEncode(parsed.toJson()), isNot(contains('workspace_ref')));
  });

  test('rejects duplicate, unknown, authority, and binding drift', () {
    final response = _response();
    final encoded = jsonEncode(response);

    final duplicate = encoded.replaceFirst(
      '"schema_version":"${ForgeRunnerTransportAdmission.schema}",',
      '"schema_version":"${ForgeRunnerTransportAdmission.schema}",'
          '"schema_version":"${ForgeRunnerTransportAdmission.schema}",',
    );
    expect(
      () => ForgeRunnerTransportAdmission.fromJsonText(duplicate),
      throwsFormatException,
    );

    final unknown = Map<String, dynamic>.from(response)
      ..['payload_body'] = '{}';
    expect(
      () => ForgeRunnerTransportAdmission.fromJson(unknown),
      throwsFormatException,
    );

    final authority = Map<String, dynamic>.from(response);
    authority['authority'] = {
      ...Map<String, dynamic>.from(authority['authority'] as Map),
      'transport_authenticated': true,
    };
    expect(
      () => ForgeRunnerTransportAdmission.fromJson(authority),
      throwsFormatException,
    );

    final pathDrift = Map<String, dynamic>.from(response)
      ..['transport_path'] = '/api/v1/runners/other/dispatch';
    expect(
      () => ForgeRunnerTransportAdmission.fromJson(pathDrift),
      throwsFormatException,
    );

    final readinessDrift = Map<String, dynamic>.from(response)
      ..['admission_ready'] = false;
    expect(
      () => ForgeRunnerTransportAdmission.fromJson(readinessDrift),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _response() => {
  'schema_version': ForgeRunnerTransportAdmission.schema,
  'evaluation_mode': ForgeRunnerTransportAdmission.evaluationMode,
  'owner': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'conversation_id': 'conversation-1',
  'run_id': 'run-1',
  'attempt_id': 'attempt-1',
  'attempt_state': 'accepted',
  'attempt_state_admissible': true,
  'command_id': 'command-1',
  'command_sha256':
      '11bd167e5ac9ee8c07f6c0c3b668853e114723f90ed39bed33e82684ded76ebe',
  'target_id': 'runner-1',
  'lease_epoch': 1,
  'lease_issued_at_ms': 100,
  'lease_expires_at_ms': 10100,
  'evaluated_at_ms': 300,
  'transport_method': 'POST',
  'transport_path': '/api/v1/runners/runner-1/dispatch',
  'transport_timestamp': 1700000000,
  'transport_nonce': 'transport-admission-1',
  'transport_payload_sha256':
      '6ad570170fca79ef62dad30b16f37314ea65f13895d4e0ea873b6512d1c99333',
  'transport_payload_bytes': 74,
  'transport_replay_checked': true,
  'lease_proof_current': true,
  'lease_active': true,
  'command_binding_valid': true,
  'transport_binding_valid': true,
  'admission_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'device_identity_verified': false,
    'transport_authenticated': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
