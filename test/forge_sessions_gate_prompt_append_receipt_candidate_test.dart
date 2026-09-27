import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _owned(String id, String title, int version) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': title,
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': version,
};

Map<String, dynamic> _prompt(
  String id,
  String conversationID,
  String content,
) => {
  'id': id,
  'conversation_id': conversationID,
  'role': 'user',
  'content': content,
  'created_at_ms': 30,
};

Map<String, dynamic> _sessionView() => {
  'schema_version': forgeClientInstanceSessionViewSchema,
  'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
  'owner_declaration': _owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': ['conversation-visible'],
      'observed_at_ms': 30,
      'status': 'active',
    },
  ],
  'read_only': true,
  'authority': const {
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

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final backend = MemoryForgeCredentialBackend();
  final store = ForgeCredentialStore(
    backend: backend,
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
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

  setUp(() => BrowserNavigation.resetForTest());
  tearDown(BrowserNavigation.resetForTest);

  testWidgets(
    'explicit Gate Prompt receipt candidate sends through the selected instance',
    (tester) async {
      final store = await _credentialStore('receipt-candidate-token');
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      var promptWritten = false;
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return _json({
            'conversations': [
              _owned('conversation-hidden', 'Hidden work', 1),
              _owned('conversation-visible', 'Visible work', 1),
            ],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            path == '/api/v1/client-instances/session-view') {
          return _json(_sessionView());
        }
        if (request.method == 'GET' &&
            path.endsWith('/conversations/conversation-hidden/prompts')) {
          return _json({
            'conversation_id': 'conversation-hidden',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            path.endsWith('/conversations/conversation-visible/prompts')) {
          return _json({
            'conversation_id': 'conversation-visible',
            'prompts': promptWritten
                ? [
                    _prompt(
                      'prompt-receipt',
                      'conversation-visible',
                      'from web',
                    ),
                  ]
                : <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' && path.endsWith('/runs')) {
          final conversationID = path.split('/')[4];
          return _json({
            'conversation_id': conversationID,
            'runs': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'POST' &&
            path == '/api/v1/conversations/conversation-visible/prompts') {
          expect(request.url.host, 'candidate.example');
          expect(
            request.headers['authorization'],
            'Bearer receipt-candidate-token',
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['content'], 'from web');
          expect(body['expected_version'], 1);
          promptWritten = true;
          return _json({
            'prompt': _prompt(
              'prompt-receipt',
              'conversation-visible',
              'from web',
            ),
            'aggregate_version': 2,
            'replayed': false,
          }, status: 201);
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            clientInstanceSessionViewOwner: _owner,
            clientInstanceSessionViewCandidateApiOrigin:
                'https://candidate.example',
            enableClientInstanceSessionViewCandidate: true,
            promptAppendReceiptOwner: _owner,
            promptAppendReceiptCandidateApiOrigin: 'https://candidate.example',
            enablePromptAppendReceiptCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      final filterMenu = find.byKey(
        const ValueKey('forge-client-instance-session-filter-menu'),
      );
      expect(filterMenu, findsOneWidget);
      await tester.ensureVisible(filterMenu);
      await tester.tap(filterMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-web-001').last);
      // The screen owns a long-lived change-feed poll. Let the local filter
      // callback render once, then use explicit request polling below;
      // pumpAndSettle would advance the fake clock into the next live poll.
      await tester.pump();
      expect(find.text('Visible work'), findsWidgets);
      expect(find.text('Hidden work'), findsNothing);

      final promptField = find.byType(TextField).last;
      await tester.ensureVisible(promptField);
      await tester.enterText(promptField, 'from web');
      final appendButton = find.widgetWithText(FilledButton, 'Append prompt');
      await tester.ensureVisible(appendButton);
      await tester.tap(appendButton);
      await _pump(tester);

      expect(find.text('from web'), findsOneWidget);
      expect(
        find.text('Prompt stored. It has not started a task.'),
        findsOneWidget,
      );
      final promptWrites = requests
          .where(
            (request) =>
                request.method == 'POST' &&
                request.url.path.endsWith('/prompts'),
          )
          .toList();
      expect(promptWrites, hasLength(1));
      expect(promptWrites.single.url.host, 'candidate.example');
      expect(promptWrites.single.headers['idempotency-key'], isNotEmpty);
    },
  );

  testWidgets('default Gate does not construct or call the receipt adapter', (
    tester,
  ) async {
    final store = await _credentialStore('default-gate-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError(
        'Default Gate opened an unexpected route: ${request.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(credentialStore: store, httpClient: client),
      ),
    );
    await _pump(tester);

    expect(requests.where((request) => request.method == 'POST'), isEmpty);
    expect(
      requests.where((request) => request.url.host == 'candidate.example'),
      isEmpty,
    );
  });

  testWidgets('receipt candidate does not replay an unauthorized append', (
    tester,
  ) async {
    final store = await _credentialStore('unauthorized-receipt-token');
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (request.method == 'GET' && path == '/api/v1/conversations') {
        return _json({
          'conversations': [
            _owned('conversation-unauthorized', 'Private work', 1),
          ],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          path.endsWith('/conversations/conversation-unauthorized/prompts')) {
        return _json({
          'conversation_id': 'conversation-unauthorized',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' && path.endsWith('/runs')) {
        return _json({
          'conversation_id': 'conversation-unauthorized',
          'runs': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'POST' && path.endsWith('/prompts')) {
        expect(request.url.host, 'candidate.example');
        return _json({
          'code': 'unauthorized',
          'message': 'private',
        }, status: 401);
      }
      throw StateError('Unexpected Forge request: ${request.method} $path');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          promptAppendReceiptOwner: _owner,
          promptAppendReceiptCandidateApiOrigin: 'https://candidate.example',
          enablePromptAppendReceiptCandidate: true,
        ),
      ),
    );
    await _pump(tester);
    final promptField = find.byType(TextField).last;
    await tester.ensureVisible(promptField);
    await tester.enterText(promptField, 'one attempt');
    final appendButton = find.widgetWithText(FilledButton, 'Append prompt');
    await tester.ensureVisible(appendButton);
    await tester.tap(appendButton);
    await _pump(tester);

    final promptWrites = requests
        .where(
          (request) =>
              request.method == 'POST' && request.url.path.endsWith('/prompts'),
        )
        .toList();
    expect(promptWrites, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      requests.where(
        (request) =>
            request.method == 'POST' && request.url.path.endsWith('/prompts'),
      ),
      hasLength(1),
    );
  });
}
