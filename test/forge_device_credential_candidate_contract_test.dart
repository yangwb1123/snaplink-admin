import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_credential_candidate.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_DEVICE_CREDENTIAL_CANDIDATE_FIXTURE'];

  test(
    'decodes the metadata-only credential candidate fixture',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final candidate =
          ForgeDeviceCredentialLifecycleCandidate.fromJsonText(source);
      final owner = const ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'user-1',
        tenantID: 'tenant-1',
      );
      expect(candidate.owner, owner);
      expect(candidate.deviceID, 'device-1');
      expect(candidate.action, 'issue');
      expect(candidate.revision, 7);
      expect(candidate.previous, isNull);
      expect(candidate.next.credentialID, 'credential-1');
      expect(candidate.next.keyGeneration, 1);
      expect(candidate.isDisplayOnly, isTrue);
      expect(candidate.toJson(), jsonDecode(source));
      final rebound = ForgeDeviceCredentialLifecycleCandidate.decodeForOwner(
        candidate.toJson(),
        owner: owner,
      );
      expect(rebound.deviceID, candidate.deviceID);
      expect(rebound.next.credentialID, candidate.next.credentialID);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects duplicate, secret, foreign-owner and enabled-authority drift', () {
    final source = File(fixturePath!).readAsStringSync();
    final duplicate = source.replaceFirst(
      '  "schema_version": "forge.device-credential-lifecycle/v1",',
      '  "schema_version": "forge.device-credential-lifecycle/v1",\n'
          '  "schema_version": "forge.device-credential-lifecycle/v1",',
    );
    expect(
      () => ForgeDeviceCredentialLifecycleCandidate.fromJsonText(duplicate),
      throwsFormatException,
    );

    final root = Map<String, dynamic>.from(jsonDecode(source) as Map);
    final secret = Map<String, dynamic>.from(root)
      ..['credential_material'] = 'secret';
    expect(
      () => ForgeDeviceCredentialLifecycleCandidate.fromJson(secret),
      throwsFormatException,
    );

    final foreign = jsonDecode(source) as Map<String, dynamic>;
    (foreign['next'] as Map<String, dynamic>)['owner'] = {
      'issuer': 'https://id.example',
      'subject': 'foreign-user',
      'tenant_id': 'tenant-1',
    };
    expect(
      () => ForgeDeviceCredentialLifecycleCandidate.fromJson(foreign),
      throwsFormatException,
    );

    final authority = jsonDecode(source) as Map<String, dynamic>;
    (authority['authority'] as Map<String, dynamic>)['persisted'] = true;
    expect(
      () => ForgeDeviceCredentialLifecycleCandidate.fromJson(authority),
      throwsFormatException,
    );
  }, skip: fixturePath == null ? 'Run through scripts/test-forge-contracts.sh.' : false);

  test('matches Core identifier alphabet', () {
    final source = File(fixturePath!).readAsStringSync();
    for (final character in ['+', '/']) {
      final device = jsonDecode(source) as Map<String, dynamic>;
      device['device_id'] = 'device${character}1';
      (device['next'] as Map<String, dynamic>)['device_id'] = 'device${character}1';
      expect(
        () => ForgeDeviceCredentialLifecycleCandidate.fromJson(device),
        throwsFormatException,
        reason: 'device identifier character $character must be rejected',
      );

      final key = jsonDecode(source) as Map<String, dynamic>;
      (key['next'] as Map<String, dynamic>)['key_id'] = 'key${character}1';
      expect(
        () => ForgeDeviceCredentialLifecycleCandidate.fromJson(key),
        throwsFormatException,
        reason: 'key identifier character $character must be rejected',
      );
    }
  }, skip: fixturePath == null ? 'Run through scripts/test-forge-contracts.sh.' : false);
}
