import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';

void main() {
  test('shared client-instance session/resource fixture is display-only', () {
    final path =
        Platform
            .environment['FORGE_CLIENT_INSTANCE_SESSION_RESOURCE_CONVERGENCE_FIXTURE'] ??
        'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json';
    final pair = ForgeClientInstanceSessionResourceConvergence.fromJsonText(
      File(path).readAsStringSync(),
    );

    expect(pair.isDisplayOnly, isTrue);
    expect(
      pair.sessionView.instances.map((instance) => instance.toJson()).toList(),
      pair.resourceView.instances.map((instance) => instance.toJson()).toList(),
    );
    expect(pair.resourceView.devices, isNotEmpty);
  });

  test(
    'independent session and resource observations fail closed on row drift',
    () {
      final path =
          Platform
              .environment['FORGE_CLIENT_INSTANCE_SESSION_RESOURCE_CONVERGENCE_FIXTURE'] ??
          'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json';
      final pair = ForgeClientInstanceSessionResourceConvergence.fromJsonText(
        File(path).readAsStringSync(),
      );
      final driftedResourceJson = pair.resourceView.toJson();
      final instances = driftedResourceJson['instances']! as List<Object?>;
      final first = Map<String, dynamic>.from(instances.first! as Map);
      first['observed_at_ms'] = (first['observed_at_ms'] as int) + 1;
      instances[0] = first;
      final driftedResource = ForgeClientInstanceResourceView.fromJson(
        driftedResourceJson,
      );

      expect(
        forgeClientInstanceSessionResourceObservationsConverged(
          pair.sessionView,
          driftedResource,
        ),
        isFalse,
      );
    },
  );

  test(
    'manually constructed session envelope with nested drift fails closed',
    () {
      final pair = ForgeClientInstanceSessionResourceConvergence.fromJsonText(
        File(
          'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json',
        ).readAsStringSync(),
      );
      final tamperedSession = ForgeClientInstanceSessionView(
        schemaVersion: pair.sessionView.schemaVersion,
        evaluationMode: 'not-display-only',
        owner: pair.sessionView.owner,
        ownerDeclarationUnverified: pair.sessionView.ownerDeclarationUnverified,
        instances: pair.sessionView.instances,
        readOnly: pair.sessionView.readOnly,
        authority: pair.sessionView.authority,
      );
      final tamperedPair = ForgeClientInstanceSessionResourceConvergence(
        schemaVersion: pair.schemaVersion,
        evaluationMode: pair.evaluationMode,
        owner: pair.owner,
        sessionView: tamperedSession,
        resourceView: pair.resourceView,
        converged: true,
        readOnly: true,
        authority: pair.authority,
      );

      expect(tamperedPair.isDisplayOnly, isFalse);
    },
  );

  test('manually constructed invalid instance row fails closed', () {
    final pair = ForgeClientInstanceSessionResourceConvergence.fromJsonText(
      File(
        'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json',
      ).readAsStringSync(),
    );
    final first = pair.sessionView.instances.first;
    final malformedSession = ForgeClientInstanceSessionView(
      schemaVersion: pair.sessionView.schemaVersion,
      evaluationMode: pair.sessionView.evaluationMode,
      owner: pair.sessionView.owner,
      ownerDeclarationUnverified: pair.sessionView.ownerDeclarationUnverified,
      instances: [
        ForgeClientInstanceSessionViewInstance(
          instanceID: first.instanceID,
          clientKind: first.clientKind,
          sessionIDs: first.sessionIDs,
          observedAtMS: first.observedAtMS,
          status: 'unexpected-status',
        ),
        ...pair.sessionView.instances.skip(1),
      ],
      readOnly: pair.sessionView.readOnly,
      authority: pair.sessionView.authority,
    );
    expect(
      forgeClientInstanceSessionResourceObservationsConverged(
        malformedSession,
        pair.resourceView,
      ),
      isFalse,
    );
  });
}
