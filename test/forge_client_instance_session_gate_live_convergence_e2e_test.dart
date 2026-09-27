import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_SESSION_GATE_LIVE_CONVERGENCE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'open Sessions Gate converges after an external Runtime CLI Prompt',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final conversationID = _requiredText(input, 'conversation_id');
      final instanceID = _requiredText(input, 'instance_id');
      final issuer = _requiredText(input, 'issuer');
      final subject = _requiredText(input, 'subject');
      final tenantID = _requiredText(input, 'tenant_id');
      final runtimeExecutable = _requiredText(input, 'runtime_executable');
      final content = _requiredText(input, 'content');
      final idempotencyKey = _requiredText(input, 'idempotency_key');

      final credentialStore = ForgeCredentialStore(
        backend: MemoryForgeCredentialBackend(),
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      addTearDown(credentialStore.clear);

      final owner = ForgeDeviceOwner(
        issuer: issuer,
        subject: subject,
        tenantID: tenantID,
      );
      tester.view.physicalSize = const Size(1280, 3200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            initialConversationID: conversationID,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewCandidateApiOrigin: apiURL,
            enableClientInstanceSessionViewCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () =>
            find
                .byKey(
                  const ValueKey('forge-client-instance-session-view-panel'),
                )
                .evaluate()
                .isNotEmpty &&
            find
                .byKey(ValueKey('forge-conversation-$conversationID'))
                .evaluate()
                .isNotEmpty,
        waitFor: 'owner session projection and selected conversation',
      );

      final filterMenu = find.byKey(
        const ValueKey('forge-client-instance-session-filter-menu'),
      );
      expect(filterMenu, findsOneWidget);
      await tester.ensureVisible(filterMenu);
      await tester.tap(filterMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(instanceID).last);
      // The screen owns a long-lived change-feed poll. Let the local filter
      // callback render once, then use the bounded convergence wait below;
      // pumpAndSettle would advance the fake clock into the next live poll.
      await tester.pump();
      await _pumpUntil(
        tester,
        () => find
            .byKey(ValueKey('forge-conversation-$conversationID'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'conversation visible through selected client instance',
      );

      final external = await tester.runAsync(
        () => _submitExternalPrompt(
          runtimeExecutable: runtimeExecutable,
          apiURL: apiURL,
          accessToken: accessToken,
          instanceID: instanceID,
          conversationID: conversationID,
          content: content,
          idempotencyKey: idempotencyKey,
        ),
      );
      if (external == null) {
        throw StateError('External Runtime CLI Prompt did not complete.');
      }
      if (external['content'] != content ||
          external['conversation_id'] != conversationID) {
        throw const FormatException(
          'Runtime CLI Prompt response did not match the external write.',
        );
      }

      // The production Sessions screen polls the owner change feed every
      // fifteen seconds. Let that real poll advance the selected history.
      await tester.pump(const Duration(seconds: 16));
      await _pumpUntil(
        tester,
        () => find.text(content).evaluate().isNotEmpty,
        waitFor: 'external Prompt in the selected session history',
      );
      expect(find.text(content), findsWidgets);
      expect(find.text(instanceID), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 21));
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid client-instance Session Gate convergence input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException(
      'Missing client-instance Session Gate convergence $key.',
    );
  }
  return value;
}

Future<Map<String, dynamic>> _submitExternalPrompt({
  required String runtimeExecutable,
  required String apiURL,
  required String accessToken,
  required String instanceID,
  required String conversationID,
  required String content,
  required String idempotencyKey,
}) async {
  final home = await Directory.systemTemp.createTemp(
    'forge-client-instance-session-convergence-',
  );
  try {
    final environment = Map<String, String>.from(Platform.environment)
      ..['FORGE_API_URL'] = apiURL
      ..['FORGE_ACCESS_TOKEN'] = accessToken
      ..['HOME'] = home.path
      ..['USERPROFILE'] = home.path
      ..['XDG_CONFIG_HOME'] = '${home.path}/config';
    final sessions = await Process.run(
      runtimeExecutable,
      ['--json', 'remote', 'sessions', 'list', '--instance', instanceID],
      workingDirectory: home.path,
      environment: environment,
    );
    if (sessions.exitCode != 0) {
      throw StateError(
        'Runtime CLI session read failed: '
        'stdout=${sessions.stdout} stderr=${sessions.stderr}',
      );
    }
    final page = jsonDecode(sessions.stdout.toString());
    if (page is! Map || page['conversations'] is! List) {
      throw const FormatException(
        'Runtime CLI session response was not a conversation page.',
      );
    }
    int? expectedVersion;
    for (final value in page['conversations'] as List) {
      if (value is! Map) continue;
      final conversation = value['conversation'];
      if (conversation is Map && conversation['id'] == conversationID) {
        final version = value['aggregate_version'];
        if (version is int) expectedVersion = version;
      }
    }
    if ((expectedVersion ?? 0) < 1) {
      throw FormatException(
        'Runtime CLI session page omitted $conversationID.',
      );
    }
    final prompt = await Process.run(
      runtimeExecutable,
      [
        '--json',
        '--idempotency-key',
        idempotencyKey,
        'remote',
        'prompts',
        'add',
        conversationID,
        '--expected-version',
        '$expectedVersion',
        '--instance',
        instanceID,
        content,
      ],
      workingDirectory: home.path,
      environment: environment,
    );
    if (prompt.exitCode != 0) {
      throw StateError(
        'Runtime CLI Prompt failed: '
        'stdout=${prompt.stdout} stderr=${prompt.stderr}',
      );
    }
    final decoded = jsonDecode(prompt.stdout.toString());
    if (decoded is! Map || decoded['prompt'] is! Map) {
      throw const FormatException(
        'Runtime CLI Prompt response omitted the stored Prompt.',
      );
    }
    return Map<String, dynamic>.from(decoded['prompt'] as Map);
  } finally {
    await home.delete(recursive: true);
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String waitFor,
}) async {
  for (var count = 0; count < 400; count++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for $waitFor from the Forge Sessions Gate.',
  );
}
