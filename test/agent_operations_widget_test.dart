import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/screens/agent/agent_event_timeline.dart';
import 'package:sso_admin/screens/agent/agent_operations_screen.dart';
import 'package:sso_admin/screens/agent/agent_session_detail.dart';
import 'package:sso_admin/session.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Future<void> _pumpAsyncRequests(WidgetTester tester) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

MockClient _scopeTestClient({required bool activeTurn}) =>
    MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/instances')) {
        return _json({
          'data': [
            {'instance_id': 'i-1', 'name': 'Runner', 'online': true},
          ],
        });
      }
      if (path.endsWith('/sessions')) {
        return _json({
          'data': [
            {
              'session_id': 's-1',
              'instance_id': 'i-1',
              'local_session_id': 'l-1',
              'name': 'Session one',
              'controllable': true,
              'status': activeTurn ? 'running' : 'idle',
            },
          ],
        });
      }
      if (path.endsWith('/sessions/s-1')) {
        return _json({
          'data': {
            'session_id': 's-1',
            'instance_id': 'i-1',
            'local_session_id': 'l-1',
            'name': 'Session one',
            'controllable': true,
            if (activeTurn) 'active_turn_id': 't-1',
          },
        });
      }
      if (path.endsWith('/events')) {
        return _json({'data': [], 'next_cursor': 0});
      }
      if (path.endsWith('/turns/t-1')) {
        return _json({
          'data': {'turn_id': 't-1', 'session_id': 's-1', 'state': 'running'},
        });
      }
      if (path.endsWith('/turns/t-1/cancel') ||
          path.endsWith('/sessions/s-1/turns')) {
        return _json({
          'error': {
            'code': 'insufficient_scope',
            'message': 'Additional Agent scope required',
          },
        }, status: 403);
      }
      throw StateError('Unexpected request: ${request.url}');
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a delayed old-session response cannot replace the new selection',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionOneDetail = Completer<http.Response>();
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.path);
        if (request.url.path.endsWith('/instances')) {
          return _json({
            'data': [
              {'instance_id': 'i-1', 'name': 'Runner', 'online': true},
            ],
          });
        }
        if (request.url.path.endsWith('/sessions')) {
          return _json({
            'data': [
              {
                'session_id': 's-1',
                'instance_id': 'i-1',
                'local_session_id': 'l-1',
                'name': 'Session one',
                'controllable': true,
                'status': 'idle',
              },
              {
                'session_id': 's-2',
                'instance_id': 'i-1',
                'local_session_id': 'l-2',
                'name': 'Session two',
                'controllable': true,
                'status': 'idle',
              },
            ],
          });
        }
        if (request.url.path.endsWith('/sessions/s-1')) {
          return sessionOneDetail.future;
        }
        if (request.url.path.endsWith('/sessions/s-2')) {
          return _json({
            'data': {
              'session_id': 's-2',
              'instance_id': 'i-1',
              'local_session_id': 'l-2',
              'name': 'Session two',
              'controllable': true,
              'status': 'idle',
            },
          });
        }
        if (request.url.path.endsWith('/events')) {
          return _json({'data': [], 'next_cursor': 0});
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: AgentOperationsScreen(
            accessToken: 'token',
            apiOrigin: 'https://hub.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpAsyncRequests(tester);
      await tester.tap(find.text('Session one').first);
      await _pumpAsyncRequests(tester);
      expect(requested, contains('/api/v1/agent/sessions/s-1'));
      await tester.tap(find.text('Session two').first);
      await _pumpAsyncRequests(tester);
      expect(
        find.descendant(
          of: find.byType(AgentSessionDetail),
          matching: find.text('Session two'),
        ),
        findsOneWidget,
      );

      sessionOneDetail.complete(
        _json({
          'data': {
            'session_id': 's-1',
            'instance_id': 'i-1',
            'local_session_id': 'l-1',
            'name': 'Stale session one detail',
            'controllable': true,
            'status': 'idle',
          },
        }),
      );
      await _pumpAsyncRequests(tester);
      expect(
        find.descendant(
          of: find.byType(AgentSessionDetail),
          matching: find.text('Session two'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AgentSessionDetail),
          matching: find.text('Stale session one detail'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('short directory pages continue when their cursor advances', (
    tester,
  ) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final isSecondPage = request.url.queryParameters['after'] != null;
      if (request.url.path.endsWith('/instances')) {
        return _json({
          'data': [
            {
              'instance_id': isSecondPage ? 'i-2' : 'i-1',
              'name': isSecondPage ? 'Runner two' : 'Runner one',
              'online': true,
            },
          ],
          'next_cursor': isSecondPage ? 'i-2' : 'i-1',
        });
      }
      if (request.url.path.endsWith('/sessions')) {
        return _json({
          'data': [
            {
              'session_id': isSecondPage ? 's-2' : 's-1',
              'instance_id': 'i-1',
              'local_session_id': isSecondPage ? 'l-2' : 'l-1',
              'name': isSecondPage ? 'Session two' : 'Session one',
            },
          ],
          'next_cursor': isSecondPage ? 's-2' : 's-1',
        });
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AgentOperationsScreen(
          accessToken: 'token',
          apiOrigin: 'https://hub.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpAsyncRequests(tester);
    expect(find.text('Load more instances'), findsOneWidget);
    expect(find.text('Load more sessions'), findsOneWidget);

    await tester.tap(find.text('Load more instances'));
    await _pumpAsyncRequests(tester);
    expect(
      requests
          .where((uri) => uri.path.endsWith('/instances'))
          .map((uri) => uri.queryParameters['after']),
      [null, 'i-1'],
    );
    expect(
      requests
          .where((uri) => uri.path.endsWith('/sessions'))
          .map((uri) => uri.queryParameters['after']),
      [null, 's-1'],
    );
  });

  testWidgets(
    'lost prompt response retries the same accepted turn idempotently',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final submittedRequests = <http.Request>[];
      final acceptedByKey = <String, String>{};
      var lostFirstResponse = false;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/instances')) {
          return _json({
            'data': [
              {'instance_id': 'i-1', 'name': 'Runner', 'online': true},
            ],
          });
        }
        if (path.endsWith('/sessions')) {
          return _json({
            'data': [
              {
                'session_id': 's-1',
                'instance_id': 'i-1',
                'local_session_id': 'l-1',
                'name': 'Session one',
                'controllable': true,
                'status': 'idle',
              },
            ],
          });
        }
        if (path.endsWith('/sessions/s-1')) {
          return _json({
            'data': {
              'session_id': 's-1',
              'instance_id': 'i-1',
              'local_session_id': 'l-1',
              'name': 'Session one',
              'controllable': true,
              'status': 'idle',
            },
          });
        }
        if (path.endsWith('/events')) {
          final after =
              int.tryParse(request.url.queryParameters['after'] ?? '0') ?? 0;
          final queued = acceptedByKey.entries
              .map(
                (entry) => {
                  'cursor': 1,
                  'event_id': 'queued-${entry.key}',
                  'session_id': 's-1',
                  'turn_id': entry.value,
                  'kind': 'turn.queued',
                  'payload': {'text': 'run the build', 'actor': 'alice'},
                },
              )
              .where((event) => (event['cursor']! as int) > after)
              .toList(growable: false);
          return _json({
            'data': queued,
            'next_cursor': queued.isEmpty ? after : 1,
          });
        }
        if (path.endsWith('/sessions/s-1/turns')) {
          submittedRequests.add(request);
          final key = request.headers['idempotency-key'];
          expect(key, isNotNull);
          final turnId = acceptedByKey.putIfAbsent(key!, () => 't-1');
          if (!lostFirstResponse) {
            lostFirstResponse = true;
            // Model the Hub commit succeeding while the transport loses the
            // HTTP response before it reaches the client.
            throw http.ClientException(
              'connection closed after request commit',
              request.url,
            );
          }
          return _json({
            'data': {'turn_id': turnId, 'session_id': 's-1', 'state': 'queued'},
          }, status: 202);
        }
        if (path.endsWith('/turns/t-1')) {
          return _json({
            'data': {'turn_id': 't-1', 'session_id': 's-1', 'state': 'queued'},
          });
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: AgentOperationsScreen(
            accessToken: 'token',
            apiOrigin: 'https://hub.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpAsyncRequests(tester);
      await tester.tap(find.text('Session one').first);
      await _pumpAsyncRequests(tester);
      await tester.enterText(find.byType(TextField), 'run the build');
      await tester.tap(find.text('Send prompt'));
      await _pumpAsyncRequests(tester);

      expect(find.text('Retry send'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'run the build',
      );

      await tester.tap(find.text('Retry send'));
      await _pumpAsyncRequests(tester);

      expect(submittedRequests, hasLength(2));
      expect(acceptedByKey, hasLength(1));
      expect(submittedRequests.map((request) => request.url.path).toSet(), {
        '/api/v1/agent/sessions/s-1/turns',
      });
      expect(
        submittedRequests
            .map((request) => request.headers['idempotency-key'])
            .toSet(),
        hasLength(1),
      );
      expect(submittedRequests.map((request) => request.body).toSet(), {
        jsonEncode({'prompt': 'run the build'}),
      });
      expect(find.text('run the build'), findsOneWidget);
      expect(find.text('Retry send'), findsNothing);
      expect(find.textContaining('Turn t-1'), findsOneWidget);
    },
  );

  testWidgets(
    'missing prompt scope offers re-login without clearing identity',
    (tester) async {
      Session.store('existing-identity-session');
      addTearDown(Session.clear);
      final client = _scopeTestClient(activeTurn: false);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: AgentOperationsScreen(
            accessToken: 'existing-identity-session',
            apiOrigin: 'https://hub.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpAsyncRequests(tester);
      await tester.tap(find.text('Session one'));
      await _pumpAsyncRequests(tester);
      await tester.enterText(find.byType(TextField), 'run the build');
      await tester.tap(find.text('Send prompt'));
      await _pumpAsyncRequests(tester);

      expect(Session.read(), 'existing-identity-session');
      expect(find.text('Sign in for Agent access'), findsOneWidget);
    },
  );

  testWidgets(
    'missing cancel scope offers re-login without clearing identity',
    (tester) async {
      Session.store('existing-identity-session');
      addTearDown(Session.clear);
      final client = _scopeTestClient(activeTurn: true);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: AgentOperationsScreen(
            accessToken: 'existing-identity-session',
            apiOrigin: 'https://hub.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpAsyncRequests(tester);
      await tester.tap(find.text('Session one'));
      await _pumpAsyncRequests(tester);
      await tester.tap(find.text('Cancel turn'));
      await _pumpAsyncRequests(tester);

      expect(Session.read(), 'existing-identity-session');
      expect(find.text('Sign in for Agent access'), findsOneWidget);
    },
  );

  testWidgets(
    '403 scope denial keeps the identity session and offers re-login',
    (tester) async {
      Session.store('existing-identity-session');
      addTearDown(Session.clear);
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/instances')) {
          return _json({
            'error': {
              'code': 'insufficient_scope',
              'message': 'Agent read scope required',
            },
          }, status: 403);
        }
        return _json({'data': []});
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: AgentOperationsScreen(
            accessToken: 'existing-identity-session',
            apiOrigin: 'https://hub.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpAsyncRequests(tester);

      expect(Session.read(), 'existing-identity-session');
      expect(find.text('Sign in for Agent access'), findsOneWidget);
    },
  );

  test(
    'timeline restores user prompts but hides terminal payload internals',
    () {
      final timeline = buildAgentTimeline([
        AgentSessionEvent(
          cursor: 1,
          eventId: 'queued',
          sessionId: 's-1',
          turnId: 't-1',
          kind: 'turn.queued',
          payload: const {'text': 'ship the report', 'actor': 'alice'},
        ),
        AgentSessionEvent(
          cursor: 2,
          eventId: 'failed',
          sessionId: 's-1',
          turnId: 't-1',
          kind: 'turn.failed',
          payload: const {'text': 'internal runner credentials'},
        ),
      ]);

      expect(timeline.first.userMessage, isTrue);
      expect(timeline.first.text, 'ship the report');
      expect(timeline.first.labelArguments['actor'], 'alice');
      expect(timeline.last.label, 'Turn failed');
      expect(timeline.last.text, isEmpty);
    },
  );

  test(
    'completed output chunks replace deltas, append, and mark truncation',
    () {
      final timeline = buildAgentTimeline([
        AgentSessionEvent(
          cursor: 1,
          eventId: 'delta',
          sessionId: 's-1',
          turnId: 't-2',
          kind: 'message.delta',
          payload: const {'text': 'partial'},
        ),
        AgentSessionEvent(
          cursor: 2,
          eventId: 'chunk-0',
          sessionId: 's-1',
          turnId: 't-2',
          kind: 'message.completed',
          payload: const {'text': 'final ', 'chunk_index': 0, 'chunk_count': 2},
        ),
        AgentSessionEvent(
          cursor: 3,
          eventId: 'chunk-1',
          sessionId: 's-1',
          turnId: 't-2',
          kind: 'message.completed',
          payload: const {
            'text': 'answer',
            'chunk_index': 1,
            'chunk_count': 2,
            'truncated': true,
          },
        ),
      ]);

      expect(timeline, hasLength(1));
      expect(timeline.single.text, 'final answer');
      expect(timeline.single.truncated, isTrue);
    },
  );
}
