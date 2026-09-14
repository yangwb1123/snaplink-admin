import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_workspace_models.dart';

import 'fixtures/agent_workspace_fixture.dart';

http.Response _json(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
AgentHubApi _api(Future<http.Response> Function(http.Request) handle) =>
    AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'token',
      httpClient: MockClient(handle),
    );

void main() {
  test(
    'workspace.ready metadata remains compatible with session event polling',
    () async {
      final api = _api(
        (_) async => _json({
          'data': [
            {
              'cursor': 1,
              'session_id': 's-1',
              'kind': 'workspace.ready',
              'payload': {
                'snapshot_id': 'snap-1',
                'sha256': workspaceBundle().sha256,
                'actor': 'other',
              },
            },
          ],
          'next_cursor': 1,
        }),
      );
      addTearDown(api.close);
      final page = await api.listEvents(sessionId: 's-1', after: 0);
      expect(page.events.single.kind, 'workspace.ready');
      expect(page.events.single.text, '');
      expect(page.nextCursor, 1);
    },
  );

  test(
    'snapshot endpoints use bearer header, bounded pagination, and explicit key',
    () async {
      final api = _api((request) async {
        expect(request.headers['authorization'], 'Bearer token');
        expect(request.url.path, '/api/v1/agent/sessions/s-1/snapshots');
        expect(request.followRedirects, isFalse);
        if (request.method == 'GET') {
          expect(request.url.queryParameters, {
            'limit': '200',
            'after': 'cursor',
          });
          return _json({
            'data': [workspaceSnapshot()],
            'next_cursor': 'next',
          });
        }
        expect(request.headers['idempotency-key'], 'stable-key');
        expect(jsonDecode(request.body), {
          'bundle': workspaceBundle().toJson(),
        });
        return _json({'data': workspaceSnapshot()});
      });
      addTearDown(api.close);
      final page = await api.listSnapshots(
        sessionId: 's-1',
        after: 'cursor',
        limit: 999,
      );
      expect(page.nextCursor, 'next');
      final snapshot = await api.uploadSnapshot(
        sessionId: 's-1',
        bundle: workspaceBundle(),
        idempotencyKey: 'stable-key',
      );
      expect(snapshot.sha256, workspaceBundle().sha256);
    },
  );

  test(
    'rejects snapshot response substitution or altered size/hash/count',
    () async {
      for (final change in [
        {'session_id': 'other'},
        {'size': 1},
        {'sha256': '0' * 64},
        {'file_count': 0},
      ]) {
        final api = _api(
          (_) async => _json({
            'data': {...workspaceSnapshot(), ...change},
          }),
        );
        await expectLater(
          api.uploadSnapshot(
            sessionId: 's-1',
            bundle: workspaceBundle(),
            idempotencyKey: 'k',
          ),
          throwsFormatException,
        );
        api.close();
      }
      final api = _api(
        (_) async => _json({
          'data': [workspaceSnapshot(session: 'other')],
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.listSnapshots(sessionId: 's-1'),
        throwsFormatException,
      );
    },
  );

  test(
    'output endpoint validates hashes and enforces bounded transport',
    () async {
      final expected = AgentWorkspaceResult.fromJson(workspaceResult());
      final api = _api((request) async {
        expect(request.url.path, '/api/v1/agent/tasks/t-1/workspace');
        expect(request.url.queryParameters, isEmpty);
        return _json({'data': workspaceOutput()});
      });
      expect(
        (await api.downloadWorkspace(
          taskId: 't-1',
          expected: expected,
        )).bundle.sha256,
        expected.outputSha256,
      );
      api.close();
      final huge = _api(
        (_) async =>
            http.Response(' ' * (AgentWorkspaceBundle.maxHttpBytes + 1), 200),
      );
      addTearDown(huge.close);
      await expectLater(
        huge.downloadWorkspace(taskId: 't', expected: expected),
        throwsA(
          isA<AgentHubApiException>().having(
            (e) => e.code,
            'code',
            'response_too_large',
          ),
        ),
      );
    },
  );

  test(
    'not-ready and permission responses never yield output or retry writes',
    () async {
      for (final status in [401, 403, 409, 500]) {
        var calls = 0;
        final api = _api((_) async {
          calls++;
          return _json({
            'error': {'code': 'denied', 'message': 'Unavailable'},
          }, status);
        });
        await expectLater(
          api.downloadWorkspace(
            taskId: 't',
            expected: AgentWorkspaceResult.fromJson(workspaceResult()),
          ),
          throwsA(
            isA<AgentHubApiException>().having(
              (e) => e.statusCode,
              'status',
              status,
            ),
          ),
        );
        expect(calls, 1);
        api.close();
      }
    },
  );
}
