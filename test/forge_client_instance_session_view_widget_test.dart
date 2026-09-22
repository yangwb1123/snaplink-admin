import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/screens/forge/forge_client_instance_session_view_panel.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(BrowserNavigation.resetForTest);

  tearDown(BrowserNavigation.resetForTest);

  testWidgets(
    'renders owner and instance metadata on the shared Web/App/Mobile surface',
    (tester) async {
      final fixture = ForgeClientInstanceSessionView.fromJson(_fixture());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ForgeClientInstanceSessionViewPanel(fixture: fixture),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
        findsOneWidget,
      );
      expect(find.text('Client instance session view'), findsOneWidget);
      expect(
        find.text('Read-only metadata; no Prompt or device authority.'),
        findsOneWidget,
      );
      expect(find.text('user-1'), findsOneWidget);
      expect(find.text('tenant-1'), findsOneWidget);
      expect(find.text('client-cli-001'), findsOneWidget);
      expect(find.text('client-web-001'), findsOneWidget);
      expect(find.textContaining('cli · active'), findsOneWidget);
      expect(find.textContaining('web · idle'), findsOneWidget);
    },
  );

  testWidgets('exposes metadata without Prompt, Run, or action controls', (
    tester,
  ) async {
    final fixture = ForgeClientInstanceSessionView.fromJson(_fixture());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeClientInstanceSessionViewPanel(fixture: fixture),
        ),
      ),
    );

    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.textContaining('Prompt'), findsOneWidget);
    expect(find.textContaining('device authority'), findsOneWidget);
  });

  testWidgets(
    'renders the injected fixture through the shared Forge Sessions screen',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        if (request.url.path == '/api/v1/conversations') {
          return http.Response(
            '{"conversations":[],"has_more":false}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/conversation-changes') {
          return http.Response(
            '{"after_cursor":0,"scanned_through_cursor":0,'
            '"has_more":false,"changes":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'fixture-access',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            clientInstanceSessionViewPreview:
                ForgeClientInstanceSessionView.fromJson(_fixture()),
          ),
        ),
      );
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
        findsOneWidget,
      );
      expect(find.text('client-cli-001'), findsOneWidget);
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
      expect(
        requests.where(
          (request) => request.url.path == '/api/v1/conversations',
        ),
        isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('loads the session view only through an explicit owner reader', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return http.Response(
          '{"conversations":[],"has_more":false}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        return http.Response(
          '{"after_cursor":0,"scanned_through_cursor":0,'
          '"has_more":false,"changes":[]}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    final owner = ForgeDeviceOwner.fromJson(
      _fixture()['owner_declaration']! as Map,
    );
    var readerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'reader-access',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          clientInstanceSessionViewOwner: owner,
          clientInstanceSessionViewReader: (requestedOwner) async {
            readerCalls++;
            expect(requestedOwner, owner);
            return ForgeClientInstanceSessionView.fromJson(_fixture());
          },
        ),
      ),
    );
    for (var count = 0; count < 8; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(readerCalls, 1);
    expect(
      find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
      findsOneWidget,
    );
    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/client-instances/session-view',
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'keeps the selected instance empty when its owner reader is revoked',
    (tester) async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'conversation': {
                    'id': 'conversation-001',
                    'scope': {'kind': 'global'},
                    'title': 'Shared from CLI and Web',
                    'created_at_ms': 10,
                    'updated_at_ms': 20,
                  },
                  'aggregate_version': 1,
                },
                {
                  'conversation': {
                    'id': 'conversation-002',
                    'scope': {'kind': 'global'},
                    'title': 'CLI-only session',
                    'created_at_ms': 11,
                    'updated_at_ms': 21,
                  },
                  'aggregate_version': 1,
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/prompts')) {
          return http.Response(
            jsonEncode({
              'conversation_id': path.split('/')[4],
              'prompts': <Object>[],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/runs')) {
          return http.Response(
            jsonEncode({
              'conversation_id': path.split('/')[4],
              'runs': <Object>[],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          return http.Response(
            '{"after_cursor":0,"scanned_through_cursor":0,'
            '"has_more":false,"changes":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      final owner = ForgeDeviceOwner.fromJson(
        _fixture()['owner_declaration']! as Map,
      );
      Widget buildScreen({required bool readerEnabled}) => MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'reader-revocation-access',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          clientInstanceSessionViewOwner: readerEnabled ? owner : null,
          clientInstanceSessionViewReader: readerEnabled
              ? (_) async => ForgeClientInstanceSessionView.fromJson(_fixture())
              : null,
        ),
      );

      await tester.pumpWidget(buildScreen(readerEnabled: true));
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-web-001').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-002')),
        findsNothing,
      );

      await tester.pumpWidget(buildScreen(readerEnabled: false));
      for (var count = 0; count < 8; count++) {
        await tester.pump();
      }

      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-002')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-session-filter')),
        findsOneWidget,
      );
      expect(
        find.text('No conversations are visible from this client instance.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'filters the owner session list by a caller-declared client instance',
    (tester) async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'conversation': {
                    'id': 'conversation-001',
                    'scope': {'kind': 'global'},
                    'title': 'Shared from CLI and Web',
                    'created_at_ms': 10,
                    'updated_at_ms': 20,
                  },
                  'aggregate_version': 1,
                },
                {
                  'conversation': {
                    'id': 'conversation-002',
                    'scope': {'kind': 'global'},
                    'title': 'CLI-only session',
                    'created_at_ms': 11,
                    'updated_at_ms': 21,
                  },
                  'aggregate_version': 1,
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/prompts')) {
          return http.Response(
            jsonEncode({
              'conversation_id': path.split('/')[4],
              'prompts': <Object>[],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/runs')) {
          return http.Response(
            jsonEncode({
              'conversation_id': path.split('/')[4],
              'runs': <Object>[],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          return http.Response(
            '{"after_cursor":0,"scanned_through_cursor":0,"has_more":false,"changes":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'filter-access',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            clientInstanceSessionViewPreview:
                ForgeClientInstanceSessionView.fromJson(_fixture()),
          ),
        ),
      );
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('forge-client-instance-session-filter')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-web-001').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        -500,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-002')),
        findsNothing,
      );
      expect(
        find.textContaining('Local display filter over the owner session list'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'does not read hidden Prompt history from a client-instance deep link',
    (tester) async {
      final promptRequests = <String>[];
      final runRequests = <String>[];
      final runObservedReads = <String>[];
      final pendingRunIntentReads = <String>[];
      final executionConsentReads = <String>[];
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'conversation': {
                    'id': 'conversation-001',
                    'scope': {'kind': 'global'},
                    'title': 'Visible web session',
                    'created_at_ms': 10,
                    'updated_at_ms': 20,
                  },
                  'aggregate_version': 1,
                },
                {
                  'conversation': {
                    'id': 'conversation-002',
                    'scope': {'kind': 'global'},
                    'title': 'Hidden web session',
                    'created_at_ms': 11,
                    'updated_at_ms': 21,
                  },
                  'aggregate_version': 1,
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/prompts')) {
          final conversationID = path.split('/')[4];
          promptRequests.add(conversationID);
          return http.Response(
            jsonEncode({
              'conversation_id': conversationID,
              'prompts': <Object>[],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/runs')) {
          final conversationID = path.split('/')[4];
          runRequests.add(conversationID);
          return http.Response(
            jsonEncode({
              'conversation_id': conversationID,
              'runs': [
                {
                  'run_id': 'run-001',
                  'prompt_id': 'prompt-001',
                  'created_at_ms': 10,
                  'latest_sequence': 1,
                  'status': 'nonterminal',
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/timeline')) {
          final segments = path.split('/');
          return http.Response(
            jsonEncode({
              'conversation_id': segments[4],
              'run_id': segments[6],
              'after_sequence': 0,
              'scanned_through_sequence': 1,
              'has_more': false,
              'events': <Object>[],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          return http.Response(
            '{"after_cursor":0,"scanned_through_cursor":0,"has_more":false,"changes":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'deep-link-filter-access',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            clientInstanceSessionViewPreview:
                ForgeClientInstanceSessionView.fromJson(_fixture()),
            executionConsentPreviewOwner: ForgeDeviceOwner.fromJson(
              _fixture()['owner_declaration']! as Map,
            ),
            executionConsentPreviewReader:
                ({required owner, required conversationID}) async {
                  executionConsentReads.add(conversationID);
                  return ForgeExecutionConsentPreview.fromJson({
                    'conversation_id': conversationID,
                    'project_id': 'project-001',
                    'profile_id': 'profile-001',
                    'profile_sha256':
                        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                    'maximum_ttl_ms': 60000,
                  });
                },
            runObservedReader: (conversationID, runID) async {
              runObservedReads.add(conversationID);
              return ForgeRunObserved.fromJson({
                'api_version': forgeRunObservedSchema,
                'owner_ref':
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'conversation_id': conversationID,
                'run_id': runID,
                'prompt_id': 'prompt-001',
                'created_at_ms': 10,
                'latest_sequence': 1,
                'status': 'nonterminal',
                'metadata_observed': true,
                'content_included': false,
                'authority': {
                  'identity_verified': false,
                  'owner_authorized': false,
                  'run_authoritative': false,
                  'persistence_attested': false,
                  'content_provenance_verified': false,
                  'reservation_created': false,
                  'execution_authorized': false,
                  'dispatch_performed': false,
                },
              });
            },
            pendingRunIntentPageReader: (conversationID, before) async {
              pendingRunIntentReads.add(conversationID);
              expect(before, isNull);
              return ForgePendingRunIntentListPage.fromJson({
                'conversation_id': conversationID,
                'intents': <Object>[],
                'has_more': false,
              }, requestedConversationID: conversationID);
            },
          ),
        ),
      );
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-web-001').last);
      await tester.pumpAndSettle();

      BrowserNavigation.pushState('/forge/conversations/conversation-002');
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(promptRequests, ['conversation-001']);
      expect(runRequests, ['conversation-001']);
      expect(runObservedReads, isNotEmpty);
      expect(runObservedReads, isNot(contains('conversation-002')));
      expect(pendingRunIntentReads, isNotEmpty);
      expect(pendingRunIntentReads, isNot(contains('conversation-002')));
      expect(executionConsentReads, isNotEmpty);
      expect(executionConsentReads, isNot(contains('conversation-002')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'revokes stale Prompt and Run state when a refreshed instance view hides and restores a session',
    (tester) async {
      final runRequests = <String>[];
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'conversation': {
                    'id': 'conversation-001',
                    'scope': {'kind': 'global'},
                    'title': 'Shared session',
                    'created_at_ms': 10,
                    'updated_at_ms': 20,
                  },
                  'aggregate_version': 1,
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/prompts')) {
          final conversationID = path.split('/')[4];
          return http.Response(
            jsonEncode({
              'conversation_id': conversationID,
              'prompts': [
                {
                  'id': 'prompt-001',
                  'conversation_id': conversationID,
                  'role': 'user',
                  'content':
                      'keep this private state out of a reappearing projection',
                  'created_at_ms': 10,
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/runs')) {
          final conversationID = path.split('/')[4];
          runRequests.add(conversationID);
          return http.Response(
            jsonEncode({
              'conversation_id': conversationID,
              'runs': [
                {
                  'run_id': 'run-001',
                  'prompt_id': 'prompt-001',
                  'created_at_ms': 10,
                  'latest_sequence': 1,
                  'status': 'nonterminal',
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/timeline')) {
          final segments = path.split('/');
          return http.Response(
            jsonEncode({
              'conversation_id': segments[4],
              'run_id': segments[6],
              'after_sequence': 0,
              'scanned_through_sequence': 1,
              'has_more': false,
              'events': <Object>[],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          return http.Response(
            '{"after_cursor":0,"scanned_through_cursor":0,"has_more":false,"changes":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      final visibleFixture = ForgeClientInstanceSessionView.fromJson(
        _fixture(webSessionIDs: const ['conversation-001']),
      );
      final hiddenFixture = ForgeClientInstanceSessionView.fromJson(
        _fixture(webSessionIDs: const <String>[]),
      );
      Widget buildScreen(ForgeClientInstanceSessionView fixture) => MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'projection-refresh-access',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          clientInstanceSessionViewPreview: fixture,
        ),
      );
      await tester.pumpWidget(buildScreen(visibleFixture));
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-web-001').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
      );
      await tester.pumpAndSettle();
      var promptSeenBeforeRevocation = false;
      for (var count = 0; count < 20; count++) {
        promptSeenBeforeRevocation =
            promptSeenBeforeRevocation ||
            find
                .text('keep this private state out of a reappearing projection')
                .evaluate()
                .isNotEmpty;
        if (find
            .byKey(const ValueKey('forge-run-run-001'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('forge-run-run-001')), findsOneWidget);
      expect(promptSeenBeforeRevocation, isTrue);

      await tester.pumpWidget(buildScreen(hiddenFixture));
      for (var count = 0; count < 8; count++) {
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('forge-run-run-001')), findsNothing);

      await tester.pumpWidget(buildScreen(visibleFixture));
      for (var count = 0; count < 8; count++) {
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('forge-run-run-001')), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      await tester.pump();
      var promptSeenAfterReappearance = false;
      for (var count = 0; count < 20; count++) {
        promptSeenAfterReappearance =
            promptSeenAfterReappearance ||
            find
                .text('keep this private state out of a reappearing projection')
                .evaluate()
                .isNotEmpty;
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();
      }
      expect(promptSeenAfterReappearance, isFalse);
      expect(runRequests, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'suppresses static Run observation and keeps a removed instance empty',
    (tester) async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'conversation': {
                    'id': 'conversation-001',
                    'scope': {'kind': 'global'},
                    'title': 'Shared static observation',
                    'created_at_ms': 10,
                    'updated_at_ms': 20,
                  },
                  'aggregate_version': 1,
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/prompts')) {
          return http.Response(
            jsonEncode({
              'conversation_id': path.split('/')[4],
              'prompts': <Object>[],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/runs')) {
          return http.Response(
            jsonEncode({
              'conversation_id': path.split('/')[4],
              'runs': [
                {
                  'run_id': 'run-001',
                  'prompt_id': 'prompt-001',
                  'created_at_ms': 10,
                  'latest_sequence': 1,
                  'status': 'nonterminal',
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/timeline')) {
          final segments = path.split('/');
          return http.Response(
            jsonEncode({
              'conversation_id': segments[4],
              'run_id': segments[6],
              'after_sequence': 0,
              'scanned_through_sequence': 1,
              'has_more': false,
              'events': <Object>[],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          return http.Response(
            '{"after_cursor":0,"scanned_through_cursor":0,"has_more":false,"changes":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      final visibleFixture = ForgeClientInstanceSessionView.fromJson(
        _fixture(webSessionIDs: const ['conversation-001']),
      );
      final hiddenFixture = ForgeClientInstanceSessionView.fromJson(
        _fixture(webSessionIDs: const <String>[]),
      );
      final removedFixture = ForgeClientInstanceSessionView.fromJson(
        _fixture(includeWebInstance: false),
      );
      final runObserved = ForgeRunObserved.fromJson({
        'api_version': forgeRunObservedSchema,
        'owner_ref':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'conversation_id': 'conversation-001',
        'run_id': 'run-001',
        'prompt_id': 'prompt-001',
        'created_at_ms': 10,
        'latest_sequence': 1,
        'status': 'nonterminal',
        'metadata_observed': true,
        'content_included': false,
        'authority': {
          'identity_verified': false,
          'owner_authorized': false,
          'run_authoritative': false,
          'persistence_attested': false,
          'content_provenance_verified': false,
          'reservation_created': false,
          'execution_authorized': false,
          'dispatch_performed': false,
        },
      });
      Widget buildScreen(ForgeClientInstanceSessionView fixture) => MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'static-observation-access',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          clientInstanceSessionViewPreview: fixture,
          runObserved: runObserved,
        ),
      );

      await tester.pumpWidget(buildScreen(visibleFixture));
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-web-001').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
      );
      await tester.pumpAndSettle();
      for (var count = 0; count < 20; count++) {
        if (find
            .byKey(const ValueKey('forge-run-run-001'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('forge-run-run-001')), findsOneWidget);
      for (var count = 0; count < 20; count++) {
        if (find
            .byKey(const ValueKey('forge-run-observed-card'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey('forge-run-observed-card')),
        findsOneWidget,
      );

      await tester.pumpWidget(buildScreen(hiddenFixture));
      for (var count = 0; count < 8; count++) {
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey('forge-run-observed-card')),
        findsNothing,
      );

      await tester.pumpWidget(buildScreen(removedFixture));
      for (var count = 0; count < 8; count++) {
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-session-filter')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

Map<String, dynamic> _fixture({
  List<String>? webSessionIDs,
  bool includeWebInstance = true,
}) => {
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
    if (includeWebInstance)
      {
        'instance_id': 'client-web-001',
        'client_kind': 'web',
        'session_ids': webSessionIDs ?? ['conversation-001'],
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
