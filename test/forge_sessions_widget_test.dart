import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_conversation_metadata_cache.dart';

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
  int createdAt,
) => {
  'id': id,
  'conversation_id': conversationID,
  'role': 'user',
  'content': content,
  'created_at_ms': createdAt,
};

String _forgeToken(String subject) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'iss': 'https://issuer.example', 'tenant_id': 'tenant-1', 'sub': subject})}.signature';
}

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 8; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

http.Response? _emptyRunPageWhenRequested(http.Request request) {
  final segments = request.url.pathSegments;
  if (request.method != 'GET' ||
      segments.length != 5 ||
      segments[0] != 'api' ||
      segments[1] != 'v1' ||
      segments[2] != 'conversations' ||
      segments[4] != 'runs') {
    return null;
  }
  return _json({
    'conversation_id': segments[3],
    'runs': <Object>[],
    'has_more': false,
  });
}

void main() {
  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() => BrowserNavigation.resetForTest());

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'keeps older Prompt history when a change-feed refresh adds a Prompt',
    (tester) async {
      final promptQueries = <String?>[];
      var changeReads = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return _json({
            'conversations': [_owned('conversation-1', 'Shared work', 2)],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            path == '/api/v1/conversations/conversation-1/prompts') {
          final before = request.url.queryParameters['before_prompt_id'];
          promptQueries.add(before);
          if (before == 'prompt-newest') {
            return _json({
              'conversation_id': 'conversation-1',
              'prompts': [
                _prompt('prompt-older', 'conversation-1', 'older history', 10),
              ],
              'has_more': true,
              'next_cursor': {'created_at_ms': 10, 'prompt_id': 'prompt-older'},
            });
          }
          if (changeReads > 0) {
            return _json({
              'conversation_id': 'conversation-1',
              'prompts': [
                _prompt(
                  'prompt-cli',
                  'conversation-1',
                  'from another client',
                  40,
                ),
                _prompt(
                  'prompt-newest',
                  'conversation-1',
                  'newest history',
                  30,
                ),
              ],
              'has_more': false,
            });
          }
          return _json({
            'conversation_id': 'conversation-1',
            'prompts': [
              _prompt('prompt-newest', 'conversation-1', 'newest history', 30),
            ],
            'has_more': true,
            'next_cursor': {'created_at_ms': 30, 'prompt_id': 'prompt-newest'},
          });
        }
        if (request.method == 'GET' &&
            path == '/api/v1/conversations/conversation-1/runs') {
          return _json({
            'conversation_id': 'conversation-1',
            'runs': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          changeReads++;
          final cursor = int.parse(
            request.url.queryParameters['after_cursor']!,
          );
          return _json({
            'after_cursor': cursor,
            'scanned_through_cursor': cursor == 0 ? 1 : cursor,
            'has_more': false,
            'changes': cursor == 0
                ? [
                    {
                      'cursor': 1,
                      'schema_version': 1,
                      'conversation_id': 'conversation-1',
                      'entity_id': 'prompt-cli',
                      'aggregate_version': 3,
                      'kind': 'prompt_appended',
                      'created_at_ms': 40,
                    },
                  ]
                : <Object>[],
          });
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: _forgeToken('prompt-merge-user'),
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      await tester.scrollUntilVisible(
        find.text('Load older prompts'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Load older prompts'));
      await _pumpRequests(tester);
      expect(find.text('older history'), findsOneWidget);
      expect(find.text('newest history'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh).last);
      await _pumpRequests(tester);

      expect(find.text('older history'), findsOneWidget);
      expect(find.text('newest history'), findsOneWidget);
      expect(find.text('from another client'), findsOneWidget);
      expect(find.text('Load older prompts'), findsOneWidget);
      expect(promptQueries, [null, 'prompt-newest', null, null]);
      expect(changeReads, 1);
    },
  );

  testWidgets('resumes the owner cursor after the screen is recreated', (
    tester,
  ) async {
    final cursors = <int>[];
    var feedRead = false;
    http.Client client() => MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 'Shared work', 1)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': feedRead
              ? [
                  _prompt(
                    'prompt-1',
                    'conversation-1',
                    'From another device',
                    30,
                  ),
                ]
              : <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        final cursor = int.parse(request.url.queryParameters['after_cursor']!);
        cursors.add(cursor);
        if (cursor == 0) {
          feedRead = true;
          return _json({
            'after_cursor': 0,
            'scanned_through_cursor': 1,
            'has_more': false,
            'changes': [
              {
                'cursor': 1,
                'schema_version': 1,
                'conversation_id': 'conversation-1',
                'entity_id': 'prompt-1',
                'aggregate_version': 2,
                'kind': 'prompt_appended',
                'created_at_ms': 30,
              },
            ],
          });
        }
        return _json({
          'after_cursor': cursor,
          'scanned_through_cursor': cursor,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    final token = _forgeToken('checkpoint-resume-user');
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: token,
          apiOrigin: 'https://forge.example',
          httpClient: client(),
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    expect(cursors, [0]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: token,
          apiOrigin: 'https://forge.example',
          httpClient: client(),
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    expect(cursors, [0, 1]);
  });

  testWidgets('refreshes shared sessions when the app returns to foreground', (
    tester,
  ) async {
    var conversationReads = 0;
    var changeReads = 0;
    final client = MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        conversationReads++;
        return _json({
          'conversations': [
            _owned(
              'conversation-1',
              conversationReads == 1 ? 'Shared work' : 'Updated from CLI',
              conversationReads,
            ),
          ],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        changeReads++;
        final cursor = int.parse(request.url.queryParameters['after_cursor']!);
        return _json({
          'after_cursor': cursor,
          'scanned_through_cursor': cursor,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: _forgeToken('foreground-resume-user'),
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(conversationReads, 1);
    expect(changeReads, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(changeReads, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpRequests(tester);

    expect(changeReads, 1);
    expect(conversationReads, 2);
    expect(find.text('Updated from CLI'), findsWidgets);
  });

  testWidgets('coalesces duplicate foreground lifecycle refreshes', (
    tester,
  ) async {
    final changeResponse = Completer<http.Response>();
    var conversationReads = 0;
    var changeReads = 0;
    final client = MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        conversationReads++;
        return _json({
          'conversations': [_owned('conversation-1', 'Shared work', 1)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        changeReads++;
        return changeResponse.future;
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: _forgeToken('duplicate-resume-user'),
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(conversationReads, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(changeReads, 1);
    changeResponse.complete(
      _json({
        'after_cursor': 0,
        'scanned_through_cursor': 0,
        'has_more': false,
        'changes': <Object>[],
      }),
    );
    await _pumpRequests(tester);

    expect(changeReads, 1);
    expect(conversationReads, 2);
  });

  testWidgets('keeps the conversation page cursor after load more fails', (
    tester,
  ) async {
    final afterIDs = <String?>[];
    var loadMoreFailure = true;
    final client = MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        final afterID = request.url.queryParameters['after_id'];
        afterIDs.add(afterID);
        if (afterID == null) {
          return _json({
            'conversations': [
              for (var index = 1; index <= 50; index++)
                _owned(
                  'conversation-${index.toString().padLeft(3, '0')}',
                  index == 1 ? 'First page' : 'Older page',
                  index,
                ),
            ],
            'has_more': true,
            'next_after_id': 'conversation-050',
          });
        }
        if (loadMoreFailure) {
          loadMoreFailure = false;
          return _json({
            'code': 'conflict',
            'message': 'The page changed while it was loading.',
          }, status: 409);
        }
        return _json({
          'conversations': [_owned('conversation-051', 'Second page', 51)],
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
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.scrollUntilVisible(
      find.text('Load more conversations'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Load more conversations'), findsOneWidget);

    await tester.tap(find.text('Load more conversations'));
    await _pumpRequests(tester);
    expect(find.text('Load more conversations'), findsOneWidget);
    expect(afterIDs, [null, 'conversation-050']);

    await tester.tap(find.text('Load more conversations'));
    await tester.pump(const Duration(milliseconds: 250));
    await _pumpRequests(tester);
    expect(find.text('Second page'), findsOneWidget);
    expect(find.text('Load more conversations'), findsNothing);
    expect(afterIDs.last, 'conversation-050');
  });

  testWidgets('periodic feed recovery retries a failed conversation snapshot', (
    tester,
  ) async {
    var conversationReads = 0;
    var conversationFailuresRemaining = 3;
    var changeReads = 0;
    final client = MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        conversationReads++;
        if (conversationFailuresRemaining > 0) {
          conversationFailuresRemaining--;
          throw Exception('temporary outage');
        }
        return _json({
          'conversations': [_owned('conversation-1', 'Recovered work', 1)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        changeReads++;
        final cursor = int.parse(request.url.queryParameters['after_cursor']!);
        return _json({
          'after_cursor': cursor,
          'scanned_through_cursor': cursor,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(conversationReads, greaterThanOrEqualTo(3));
    expect(find.text('Could not reach Forge.'), findsOneWidget);

    final readsBeforeRecovery = conversationReads;
    await tester.pump(const Duration(seconds: 15));
    await _pumpRequests(tester);

    expect(changeReads, greaterThanOrEqualTo(1));
    expect(conversationReads, greaterThan(readsBeforeRecovery));
    expect(find.text('Recovered work'), findsWidgets);
    expect(find.text('Could not reach Forge.'), findsNothing);
  });

  testWidgets(
    'shows owner-bound cached metadata when the first read is offline',
    (tester) async {
      final token = _forgeToken('offline-cache-user');
      final cache = ForgeConversationMetadataCache(
        accessToken: token,
        apiOrigin: 'https://forge.example',
        clientId: 'forge-console',
        resource: 'forge-api',
      );
      expect(
        await cache.save([
          ForgeOwnedConversation(
            conversation: ForgeConversation(
              id: 'conversation-cached',
              scope: const ForgeConversationScope(kind: 'global'),
              title: 'Cached offline work',
              createdAtMS: 10,
              updatedAtMS: 20,
            ),
            aggregateVersion: 2,
          ),
        ]),
        isTrue,
      );

      final client = MockClient((request) async {
        throw Exception('offline');
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: token,
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(find.text('Cached offline work'), findsWidgets);
      expect(
        find.text(
          'Forge is offline or unavailable. Showing cached session metadata; it may be stale.',
        ),
        findsOneWidget,
      );
      expect(find.text('Could not reach Forge.'), findsNothing);
    },
  );

  testWidgets(
    'authorization failure clears visible sessions instead of showing stale data',
    (tester) async {
      var conversationReads = 0;
      var changeReads = 0;
      final client = MockClient((request) async {
        final emptyRuns = _emptyRunPageWhenRequested(request);
        if (emptyRuns != null) return emptyRuns;
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          conversationReads++;
          if (conversationReads == 1) {
            return _json({
              'conversations': [_owned('conversation-1', 'Private work', 1)],
              'has_more': false,
            });
          }
          return _json({
            'error': {'code': 'unauthorized', 'message': 'private'},
          }, status: 401);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversation-changes') {
          changeReads++;
          return _json({
            'error': {'code': 'unauthorized', 'message': 'private'},
          }, status: 401);
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(find.text('Private work'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.refresh),
        ),
      );
      await _pumpRequests(tester);

      expect(
        find.text(
          'Forge access is missing. Sign in with Forge conversation permissions.',
        ),
        findsNWidgets(2),
      );
      expect(find.text('Private work'), findsNothing);

      final readsAfterAuthorizationFailure = conversationReads;
      final changesAfterAuthorizationFailure = changeReads;
      await tester.pump(const Duration(seconds: 16));
      expect(
        conversationReads,
        readsAfterAuthorizationFailure,
        reason: 'authorization failure must stop the foreground poller',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 16));
      expect(conversationReads, readsAfterAuthorizationFailure);
      expect(
        changeReads,
        changesAfterAuthorizationFailure,
        reason: 'authorization failure must block resume polling',
      );
    },
  );

  testWidgets(
    'deterministic conversation errors clear the old list instead of marking it offline',
    (tester) async {
      var conversationReads = 0;
      final client = MockClient((request) async {
        final emptyRuns = _emptyRunPageWhenRequested(request);
        if (emptyRuns != null) return emptyRuns;
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          conversationReads++;
          if (conversationReads == 1) {
            return _json({
              'conversations': [_owned('conversation-1', 'Private work', 1)],
              'has_more': false,
            });
          }
          return _json({
            'code': 'invalid_request',
            'message': 'bad page',
          }, status: 400);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversation-changes') {
          return _json({
            'after_cursor': 0,
            'scanned_through_cursor': 0,
            'has_more': false,
            'changes': <Object>[],
          });
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: _forgeToken('deterministic-error-user'),
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(find.text('Private work'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.refresh),
        ),
      );
      await _pumpRequests(tester);

      expect(find.text('Private work'), findsNothing);
      expect(find.text('bad page'), findsWidgets);
      expect(
        find.text(
          'Forge is offline or unavailable. Showing cached session metadata; it may be stale.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'feed authorization failure ends an in-flight initial conversation load',
    (tester) async {
      final conversations = Completer<http.Response>();
      var feedReads = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return conversations.future;
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversation-changes') {
          feedReads++;
          return _json({
            'error': {'code': 'unauthorized', 'message': 'private'},
          }, status: 401);
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: _forgeToken('feed-auth-race-user'),
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pumpRequests(tester);

      expect(feedReads, 1);
      expect(
        find.text(
          'Forge access is missing. Sign in with Forge conversation permissions.',
        ),
        findsWidgets,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      conversations.complete(
        _json({
          'conversations': [_owned('conversation-1', 'Late work', 1)],
          'has_more': false,
        }),
      );
      await _pumpRequests(tester);
      expect(find.text('Late work'), findsNothing);
    },
  );

  testWidgets('keeps the cursor when bounded history retries fail', (
    tester,
  ) async {
    final cursors = <int>[];
    var feedRead = false;
    var failHistoryRemaining = 3;
    final client = MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 'Shared work', 1)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        if (feedRead && failHistoryRemaining > 0) {
          failHistoryRemaining--;
          return _json({'error': 'unavailable'}, status: 503);
        }
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': feedRead
              ? [
                  _prompt(
                    'prompt-1',
                    'conversation-1',
                    'From another device',
                    30,
                  ),
                ]
              : <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        final cursor = int.parse(request.url.queryParameters['after_cursor']!);
        cursors.add(cursor);
        feedRead = true;
        return _json({
          'after_cursor': cursor,
          'scanned_through_cursor': cursor == 0 ? 1 : cursor,
          'has_more': false,
          'changes': cursor == 0
              ? [
                  {
                    'cursor': 1,
                    'schema_version': 1,
                    'conversation_id': 'conversation-1',
                    'entity_id': 'prompt-1',
                    'aggregate_version': 2,
                    'kind': 'prompt_appended',
                    'created_at_ms': 30,
                  },
                ]
              : <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    final token = _forgeToken('checkpoint-history-failure-user');
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: token,
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();

    expect(cursors, [0]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: token,
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();

    expect(cursors.length, greaterThanOrEqualTo(2));
    expect(cursors[0], 0);
    expect(cursors[1], 0);
  });

  testWidgets(
    'keeps a newer feed version when an older load-more page returns late',
    (tester) async {
      final delayedOlderPage = Completer<http.Response>();
      var conversationReads = 0;
      var feedReads = 0;
      final client = MockClient((request) async {
        final emptyRuns = _emptyRunPageWhenRequested(request);
        if (emptyRuns != null) return emptyRuns;
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          conversationReads++;
          if (request.url.queryParameters['after_id'] == 'conversation-050') {
            return delayedOlderPage.future;
          }
          return _json({
            'conversations': [
              for (var index = 1; index <= 50; index++)
                _owned(
                  'conversation-${index.toString().padLeft(3, '0')}',
                  index == 1 ? 'Shared work' : 'Older work',
                  1,
                ),
            ],
            'has_more': true,
            'next_after_id': 'conversation-050',
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversation-changes') {
          feedReads++;
          final cursor = int.parse(
            request.url.queryParameters['after_cursor']!,
          );
          return _json({
            'after_cursor': cursor,
            'scanned_through_cursor': 1,
            'has_more': false,
            'changes': [
              {
                'cursor': 1,
                'schema_version': 1,
                'conversation_id': 'conversation-001',
                'entity_id': 'prompt-1',
                'aggregate_version': 2,
                'kind': 'prompt_appended',
                'created_at_ms': 30,
              },
            ],
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
        if (request.method == 'POST' &&
            request.url.path ==
                '/api/v1/conversations/conversation-001/prompts') {
          expect(jsonDecode(request.body)['expected_version'], 2);
          return _json({
            'prompt': _prompt('prompt-new', 'conversation-001', 'send', 40),
            'aggregate_version': 3,
            'replayed': false,
          }, status: 201);
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      await tester.scrollUntilVisible(
        find.text('Load more conversations'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Load more conversations'));
      await tester.pump();
      expect(conversationReads, 2);

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.refresh),
        ),
      );
      await _pumpRequests(tester);
      expect(feedReads, 1);
      delayedOlderPage.complete(
        _json({
          'conversations': [_owned('conversation-051', 'Older work', 1)],
          'has_more': false,
        }),
      );
      await _pumpRequests(tester);
      await tester.scrollUntilVisible(
        find.text('Prompt history'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField).last, 'send');
      await tester.tap(find.widgetWithText(FilledButton, 'Append prompt'));
      await _pumpRequests(tester);
    },
  );

  testWidgets('refresh applies another device prompt from the owner feed', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 'Shared work', 2)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        expect(request.url.queryParameters['after_cursor'], '0');
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 2,
          'has_more': false,
          'changes': [
            {
              'cursor': 1,
              'schema_version': 1,
              'conversation_id': 'conversation-1',
              'entity_id': 'conversation-1',
              'aggregate_version': 1,
              'kind': 'conversation_created',
              'created_at_ms': 10,
            },
            {
              'cursor': 2,
              'schema_version': 1,
              'conversation_id': 'conversation-1',
              'entity_id': 'prompt-2',
              'aggregate_version': 2,
              'kind': 'prompt_appended',
              'created_at_ms': 40,
            },
          ],
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        final refreshed = requests
            .where((value) => value.url.path.endsWith('/conversation-changes'))
            .isNotEmpty;
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': [
            if (refreshed)
              _prompt('prompt-2', 'conversation-1', 'Second device', 40),
            _prompt('prompt-1', 'conversation-1', 'First device', 30),
          ],
          'has_more': false,
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(find.text('Second device'), findsNothing);

    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    await tester.scrollUntilVisible(
      find.text('Prompt history'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .any((widget) => widget.data == 'Second device'),
      isTrue,
      reason: 'The current conversation history should be refreshed.',
    );
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/conversation-changes',
      ),
      hasLength(1),
    );
  });

  testWidgets(
    'resnapshots when a feed change targets an unloaded conversation',
    (tester) async {
      var conversationReads = 0;
      var changeReads = 0;
      final client = MockClient((request) async {
        final emptyRuns = _emptyRunPageWhenRequested(request);
        if (emptyRuns != null) return emptyRuns;
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          conversationReads++;
          return _json({
            'conversations': conversationReads == 1
                ? [_owned('conversation-1', 'Loaded work', 1)]
                : [
                    _owned('conversation-1', 'Loaded work', 1),
                    _owned('conversation-2', 'Unloaded work', 2),
                  ],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversation-changes') {
          changeReads++;
          final cursor = int.parse(
            request.url.queryParameters['after_cursor']!,
          );
          if (cursor == 0) {
            return _json({
              'after_cursor': 0,
              'scanned_through_cursor': 1,
              'has_more': false,
              'changes': [
                {
                  'cursor': 1,
                  'schema_version': 1,
                  'conversation_id': 'conversation-2',
                  'entity_id': 'prompt-2',
                  'aggregate_version': 2,
                  'kind': 'prompt_appended',
                  'created_at_ms': 30,
                },
              ],
            });
          }
          return _json({
            'after_cursor': cursor,
            'scanned_through_cursor': cursor,
            'has_more': false,
            'changes': <Object>[],
          });
        }
        if (request.method == 'GET' && request.url.path.endsWith('/prompts')) {
          return _json({
            'conversation_id': request.url.pathSegments[3],
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: _forgeToken('unloaded-change-user'),
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(conversationReads, 1);
      expect(find.text('Unloaded work'), findsNothing);

      // The periodic path calls _syncChanges without the unconditional
      // foreground snapshot. The feed event must therefore trigger the
      // bounded resnapshot itself before its cursor is persisted.
      await tester.pump(const Duration(seconds: 15));
      await _pumpRequests(tester);

      expect(changeReads, 1);
      expect(conversationReads, 2);
      expect(find.text('Unloaded work'), findsOneWidget);
    },
  );

  testWidgets('backs off failed feed polls and resets after recovery', (
    tester,
  ) async {
    var changeReads = 0;
    final client = MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 'Shared work', 1)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        changeReads++;
        if (changeReads == 1) return _json({'unexpected': true});
        final cursor = int.parse(request.url.queryParameters['after_cursor']!);
        return _json({
          'after_cursor': cursor,
          'scanned_through_cursor': cursor,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: _forgeToken('adaptive-poll-user'),
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(changeReads, 0);

    // The first failure expands the one-shot delay from 15s to 30s.
    await tester.pump(const Duration(seconds: 15));
    await _pumpRequests(tester);
    expect(changeReads, 1);
    await tester.pump(const Duration(seconds: 29));
    await _pumpRequests(tester);
    expect(changeReads, 1);

    // A successful empty page is still a transport recovery and resets the
    // next delay to the base 15s interval.
    await tester.pump(const Duration(seconds: 1));
    await _pumpRequests(tester);
    expect(changeReads, 2);
    await tester.pump(const Duration(seconds: 14));
    await _pumpRequests(tester);
    expect(changeReads, 2);
    await tester.pump(const Duration(seconds: 2));
    await _pumpRequests(tester);
    expect(changeReads, 3);
  });

  testWidgets('browses, creates, and appends with stable idempotency on retry', (
    tester,
  ) async {
    const promptWithWhitespace = '  Run focused tests\n';
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    var appendCount = 0;
    final client = MockClient((request) async {
      requests.add(request);
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 'Existing work', 5)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': [_prompt('prompt-1', 'conversation-1', 'Review logs', 30)],
          'has_more': false,
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/conversations') {
        expect(jsonDecode(request.body), {
          'scope': {'kind': 'global'},
          'title': 'New work',
        });
        return _json({
          'id': 'conversation-2',
          'scope': {'kind': 'global'},
          'title': 'New work',
          'created_at_ms': 40,
          'updated_at_ms': 40,
        }, status: 201);
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-2/prompts') {
        return _json({
          'conversation_id': 'conversation-2',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/conversations/conversation-2/prompts') {
        appendCount++;
        expect(jsonDecode(request.body), {
          'content': promptWithWhitespace,
          'expected_version': 1,
        });
        if (appendCount == 1) throw Exception('connection interrupted');
        return _json({
          'prompt': _prompt(
            'prompt-2',
            'conversation-2',
            promptWithWhitespace,
            50,
          ),
          'aggregate_version': 2,
          'replayed': true,
        }, status: 201);
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(requests, hasLength(3));
    expect(requests.first.url.path, '/api/v1/conversations');
    expect(
      requests[1].url.path,
      '/api/v1/conversations/conversation-1/prompts',
    );
    expect(requests[2].url.path, '/api/v1/conversations/conversation-1/runs');
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(visibleText, contains('Existing work'), reason: '$visibleText');
    expect(find.text('Existing work'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'New work');
    await tester.tap(find.widgetWithText(FilledButton, 'Create conversation'));
    await _pumpRequests(tester);

    expect(find.text('New work'), findsWidgets);
    expect(
      BrowserNavigation.currentUri.path,
      '/forge/conversations/conversation-2',
    );
    expect(
      requests.where((request) => request.method == 'GET').length,
      5,
      reason: 'URL replacement must not trigger another list/detail read',
    );
    await tester.scrollUntilVisible(
      find.text('Prompt history'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, promptWithWhitespace);
    await tester.tap(find.widgetWithText(FilledButton, 'Append prompt'));
    await _pumpRequests(tester);
    expect(find.text('Could not reach Forge.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry prompt'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Retry prompt'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retry prompt'));
    await _pumpRequests(tester);

    expect(find.textContaining('Run focused tests'), findsWidgets);
    expect(
      find.text(
        'Prompt retry replayed the existing message. It has not started a task.',
      ),
      findsOneWidget,
    );
    expect(appendCount, 2);
    final appendRequests = requests
        .where(
          (request) =>
              request.method == 'POST' && request.url.path.endsWith('/prompts'),
        )
        .toList();
    expect(appendRequests, hasLength(2));
    expect(
      appendRequests[0].headers['idempotency-key'],
      matches(RegExp(r'^[0-9a-f-]{36}$')),
    );
    expect(
      appendRequests[1].headers['idempotency-key'],
      appendRequests[0].headers['idempotency-key'],
    );
  });

  testWidgets(
    'create retry keeps the old URL until the server confirms creation',
    (tester) async {
      BrowserNavigation.replaceState('/forge');
      var createAttempts = 0;
      final client = MockClient((request) async {
        final emptyRuns = _emptyRunPageWhenRequested(request);
        if (emptyRuns != null) return emptyRuns;
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/conversations') {
          createAttempts++;
          if (createAttempts == 1) throw Exception('connection interrupted');
          return _json({
            'id': 'conversation-retry',
            'scope': {'kind': 'global'},
            'title': 'Retry work',
            'created_at_ms': 40,
            'updated_at_ms': 40,
          }, status: 201);
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-retry/prompts') {
          return _json({
            'conversation_id': 'conversation-retry',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      await tester.enterText(find.byType(TextField).first, 'Retry work');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create conversation'),
      );
      await _pumpRequests(tester);

      expect(createAttempts, 1);
      expect(BrowserNavigation.currentUri.path, '/forge');
      expect(find.widgetWithText(FilledButton, 'Retry create'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Retry create'));
      await _pumpRequests(tester);

      expect(createAttempts, 2);
      expect(
        BrowserNavigation.currentUri.path,
        '/forge/conversations/conversation-retry',
      );
    },
  );
}
