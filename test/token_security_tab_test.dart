import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/token_security_tab.dart';

void main() {
  testWidgets('sections filter cards and mutation bodies match Snaplink', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final posts = <String, Map<String, dynamic>>{};
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          posts[request.url.path] = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return request.url.path.endsWith('/temp')
              ? http.Response('{"token":"one-time-token"}', 200)
              : http.Response('{}', 200);
        }
        expect(request.method, 'GET');
        final body = switch (request.url.path) {
          '/api/v1/admin/sessions' => '{"sessions":[],"total":0}',
          '/api/v1/admin/tokens' => '{"tokens":[]}',
          '/api/v1/admin/tokens/portfolio' => '{"portfolio":{}}',
          '/api/v1/admin/tokens/expiring' => '{"tokens":[]}',
          '/api/v1/admin/tokens/suspicious' => '{"findings":[]}',
          _ => '{}',
        };
        return http.Response(body, 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TokenSecurityTab(
            api: api,
            capabilities: SnaplinkAdminCapabilities(
              SnaplinkAdminOperationCatalog.endpoints,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Temp Token'));
    await tester.pumpAndSettle();
    expect(find.text('Create temporary token'), findsOneWidget);
    expect(find.text('Bounded refresh-token revocation'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('temp-token-user-id')),
      'user-123',
    );
    await tester.tap(find.byKey(const Key('temp-token-submit')));
    await tester.pumpAndSettle();
    expect(posts, isNot(contains('/api/v1/admin/tokens/temp')));
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'user-123',
    );
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(posts['/api/v1/admin/tokens/temp'], {
      'user_id': 'user-123',
      'scopes': ['openid', 'profile'],
    });
    expect(find.text('one-time-token'), findsOneWidget);
    await tester.tap(find.text('I have saved it — clear token'));
    await tester.pumpAndSettle();
    expect(find.text('one-time-token'), findsNothing);

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Create temporary token'), findsNothing);
    expect(find.text('Bounded refresh-token revocation'), findsOneWidget);
    expect(find.text('Revoke token or session'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('single-revoke-value')),
      'session-123',
    );
    await tester.tap(find.byKey(const Key('single-revoke-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'session-123',
    );
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(posts['/api/v1/admin/tokens/revoke'], {'session_id': 'session-123'});
  });

  testWidgets(
    'unknown temporary-token result locks retry until reconciliation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var tempPosts = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path.endsWith('/temp')) {
            tempPosts++;
            return http.Response('{"error":"gateway"}', 503);
          }
          return http.Response('{}', 200);
        }),
      )..maxRetries = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TokenSecurityTab(
              api: api,
              capabilities: SnaplinkAdminCapabilities(
                SnaplinkAdminOperationCatalog.endpoints,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temp Token'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('temp-token-user-id')),
        'user-unknown',
      );
      await tester.tap(find.byKey(const Key('temp-token-submit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'user-unknown',
      );
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(tempPosts, 1);
      expect(find.text('Previous write outcome is unknown'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('temp-token-submit')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('I reconciled server state'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'RECONCILED',
      );
      await tester.pump();
      await tester.tap(find.text('Unlock token writes'));
      await tester.pumpAndSettle();
      expect(find.text('Previous write outcome is unknown'), findsNothing);
    },
  );
}
