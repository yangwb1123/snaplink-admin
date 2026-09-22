import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'execution-consent-user',
  tenantID: 'tenant-1',
);

const _profileDigest =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Consent preview session',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _preview() => {
  'conversation_id': 'conversation-001',
  'project_id': 'project-001',
  'profile_id': 'profile-001',
  'profile_sha256': _profileDigest,
  'maximum_ttl_ms': 2592000000,
};

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(BrowserNavigation.resetForTest);

  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets('explicit Gate reads one selected Conversation preview', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('consent-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_conversation()],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-001/prompts') {
        return _json({
          'conversation_id': 'conversation-001',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-001/runs') {
        return _json({
          'conversation_id': 'conversation-001',
          'runs': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-001/execution-consents') {
        expect(request.url.origin, 'https://candidate.example');
        expect(request.url.query, isEmpty);
        expect(request.body, isEmpty);
        expect(request.headers['authorization'], 'Bearer consent-token');
        return _json(_preview());
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          executionConsentPreviewOwner: _owner,
          enableExecutionConsentPreviewCandidate: true,
          executionConsentPreviewCandidateApiOrigin:
              'https://candidate.example',
        ),
      ),
    );
    await _settle(tester);

    final previewRequests = requests
        .where((request) => request.url.path.endsWith('/execution-consents'))
        .toList();
    expect(previewRequests, hasLength(1));
    expect(
      find.byKey(const ValueKey('forge-execution-consent-preview-card')),
      findsOneWidget,
    );
    expect(find.text('Execution consent preview'), findsOneWidget);
    expect(find.text('project-001'), findsOneWidget);
    expect(
      find.text(
        'Preview only · consent has not been granted; no Run or device was selected.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('default Gate keeps execution-consent preview request-free', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('default-consent-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted a candidate route: $request');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          executionConsentPreviewOwner: _owner,
          executionConsentPreviewCandidateApiOrigin:
              'https://candidate.example',
        ),
      ),
    );
    await _settle(tester);

    expect(
      requests.where(
        (request) => request.url.path.endsWith('/execution-consents'),
      ),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('forge-execution-consent-preview-card')),
      findsNothing,
    );
  });
}
