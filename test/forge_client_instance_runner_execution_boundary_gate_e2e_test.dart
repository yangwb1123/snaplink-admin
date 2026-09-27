import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_execution_boundary.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

/// The Go harness supplies a real Snaplink JWT and a test-only candidate mux.
/// This drives the same Sessions Gate used by Web, desktop App, and Mobile so
/// the recorder can prove the final read-only convergence fence before POST.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_RUNNER_EXECUTION_BOUNDARY_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated Sessions Gate binds client-instance pair before execution-boundary preview',
    (tester) async {
      if (inputPath == null) return;
      final input = _readInput(inputPath);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final clientKinds = _requiredKinds(input['client_kinds']);
      final expectCard = input['expect_execution_boundary_card'] == true;
      final request = ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(
        input['request'],
      );
      if (request.owner != owner) {
        throw const FormatException(
          'Execution-boundary Gate owner does not match the request.',
        );
      }

      for (final clientKind in clientKinds) {
        final credentialStore = ForgeCredentialStore(
          backend: MemoryForgeCredentialBackend(),
          forcePersistentStorage: true,
        );
        expect(await credentialStore.store(accessToken: accessToken), isTrue);
        await tester.pumpWidget(
          MaterialApp(
            home: ForgeSessionsGate(
              credentialStore: credentialStore,
              initialConversationID: request.conversationID,
              initialClientInstanceID: 'client-$clientKind-001',
              clientInstanceSessionViewOwner: owner,
              clientInstanceSessionViewCandidateApiOrigin: apiURL,
              enableClientInstanceSessionViewCandidate: true,
              clientInstanceResourceViewOwner: owner,
              clientInstanceResourceViewCandidateApiOrigin: apiURL,
              enableClientInstanceResourceViewCandidate: true,
              deviceInventoryOwner: owner,
              deviceInventoryV2CandidateApiOrigin: apiURL,
              enableDeviceInventoryV2Candidate: true,
              runnerExecutionBoundaryRequest: request,
              runnerExecutionBoundaryCandidateApiOrigin: apiURL,
              enableRunnerExecutionBoundaryCandidate: true,
            ),
          ),
        );

        if (expectCard) {
          await _pumpUntil(
            tester,
            () => find
                .byKey(const ValueKey('forge-runner-execution-boundary-card'))
                .evaluate()
                .isNotEmpty,
          );
          expect(
            find.byKey(const ValueKey('forge-runner-execution-boundary-card')),
            findsOneWidget,
          );
          expect(
            find.text(request.command.leaseProof.targetID),
            findsOneWidget,
          );
          expect(
            find.text('Runner execution boundary preview'),
            findsOneWidget,
          );
          expect(
            find.text(request.command.leaseProof.fencingToken),
            findsNothing,
          );
          expect(find.text(request.command.workspaceRef), findsNothing);
          expect(find.text(request.command.argv.first), findsNothing);
        } else {
          await _pumpFor(tester);
          expect(
            find.byKey(const ValueKey('forge-runner-execution-boundary-card')),
            findsNothing,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await credentialStore.clear();
      }
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge client-instance execution-boundary Gate input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Forge execution-boundary Gate $key.');
  }
  return value;
}

List<String> _requiredKinds(Object? value) {
  if (value is! List || value.isEmpty) {
    throw const FormatException(
      'Missing Forge execution-boundary Gate client kinds.',
    );
  }
  final kinds = value.whereType<String>().toList(growable: false);
  if (kinds.length != value.length ||
      kinds.any((kind) => !{'web', 'app', 'mobile'}.contains(kind))) {
    throw const FormatException(
      'Invalid Forge execution-boundary Gate client kinds.',
    );
  }
  return kinds;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var index = 0; index < 360; index++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<void> _pumpFor(WidgetTester tester) async {
  for (var index = 0; index < 120; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}
