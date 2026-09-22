import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_aero_id_profile_projection.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_AERO_ID_PROFILE_PROJECTION_FIXTURE'];

  test(
    'decodes the bounded Aero-ID profile projection and binds its owner',
    () {
      final projection = ForgeAeroIDProfileProjection.fromJson(
        jsonDecode(File(fixturePath!).readAsStringSync()),
      );
      expect(projection.owner.tenantID, 'tenant-a');
      expect(
        projection.profile.accountID,
        '11111111-1111-4111-8111-111111111111',
      );
      expect(projection.memberships, hasLength(2));
      expect(projection.authority.isAllFalse, isTrue);
      projection.bindOwner(projection.owner);
      expect(
        () => projection.bindOwner(
          ForgeAeroIDProfileProjectionOwner(
            issuer: projection.owner.issuer,
            subject: projection.owner.subject,
            tenantID: 'tenant-foreign',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unknown, authority-bearing, and confused membership projections',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      final authority = Map<String, dynamic>.from(root['authority'] as Map)
        ..['authorization_granted'] = true;
      final unknown = Map<String, dynamic>.from(root)..['unexpected'] = true;
      final memberships = List<dynamic>.from(root['memberships'] as List);
      final unsorted = Map<String, dynamic>.from(root)
        ..['memberships'] = <dynamic>[memberships[1], memberships[0]];
      for (final value in [
        unknown,
        Map<String, dynamic>.from(root)..['authority'] = authority,
        unsorted,
      ]) {
        expect(
          () => ForgeAeroIDProfileProjection.fromJson(value),
          throwsA(isA<FormatException>()),
        );
      }
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}
