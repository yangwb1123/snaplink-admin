import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/credentials_tab.dart';
import 'package:sso_admin/screens/admin/crypto_keys_tab.dart';
import 'package:sso_admin/screens/admin/domains_tab.dart';
import 'package:sso_admin/screens/admin/dr_mode_tab.dart';
import 'package:sso_admin/screens/admin/threat_policies_tab.dart';
import 'package:sso_admin/screens/admin/token_exchange_tab.dart';
import 'package:sso_admin/screens/admin/token_policies_tab.dart';
import 'package:sso_admin/screens/admin/webhooks_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';

SnaplinkAdminApi _api(
  Map<String, http.Response Function(http.Request)> routes,
) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    final handler = routes[request.url.path];
    if (handler != null) return handler(request);
    return http.Response('{"error":"not found"}', 404);
  }),
);

SnaplinkAdminCapabilities _caps(List<String> paths) =>
    SnaplinkAdminCapabilities([
      for (final path in paths)
        SnaplinkAdminEndpoint(method: 'GET', path: path, feature: 'core'),
    ]);

/// These tabs stack several cards in one ListView; a tall viewport keeps the
/// whole tree laid out so finders work without scrolling.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

Finder _dialogField() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('WebhooksTab', () {
    testWidgets('loads subscriptions and dead letters on entry', (
      tester,
    ) async {
      final api = _api({
        '/api/v1/admin/webhooks/subscriptions': (_) => http.Response(
          jsonEncode({
            'subscriptions': [
              {
                'id': 'sub-1',
                'url': 'https://hooks.example/cb',
                'active': true,
              },
            ],
          }),
          200,
        ),
        '/api/v1/admin/webhooks/deadletters': (_) => http.Response(
          jsonEncode({
            'deadletters': [
              {'id': 'msg-1', 'error': 'timeout'},
            ],
          }),
          200,
        ),
      });
      await _pump(
        tester,
        WebhooksTab(
          api: api,
          capabilities: _caps([
            '/api/v1/admin/webhooks/subscriptions',
            '/api/v1/admin/webhooks/deadletters',
          ]),
        ),
      );

      expect(find.text('https://hooks.example/cb'), findsOneWidget);
      expect(find.textContaining('msg-1'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);
    });

    testWidgets('deletes a subscription with typed confirmation', (
      tester,
    ) async {
      var deleted = <String>[];
      final api = _api({
        '/api/v1/admin/webhooks/subscriptions': (_) => http.Response(
          jsonEncode({
            'subscriptions': [
              {
                'id': 'sub-1',
                'url': 'https://hooks.example/cb',
                'active': true,
              },
            ],
          }),
          200,
        ),
        '/api/v1/admin/webhooks/subscriptions/sub-1': (request) {
          if (request.method == 'DELETE') deleted.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await _pump(
        tester,
        WebhooksTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/webhooks/subscriptions']),
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.enterText(_dialogField(), 'sub-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(deleted, ['/api/v1/admin/webhooks/subscriptions/sub-1']);
      expect(find.text('Subscription deleted.'), findsOneWidget);
    });

    testWidgets('replays a dead letter and reports cleanup status', (
      tester,
    ) async {
      var replayed = <String>[];
      final api = _api({
        '/api/v1/admin/webhooks/subscriptions': (_) =>
            http.Response(jsonEncode({'subscriptions': []}), 200),
        '/api/v1/admin/webhooks/deadletters': (_) => http.Response(
          jsonEncode({
            'deadletters': [
              {'id': 'msg-1', 'error': 'timeout'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/webhooks/deadletters/msg-1/replay': (request) {
          replayed.add(request.url.path);
          return http.Response(jsonEncode({'cleanup_status': 'pending'}), 200);
        },
      });
      await _pump(
        tester,
        WebhooksTab(
          api: api,
          capabilities: _caps([
            '/api/v1/admin/webhooks/subscriptions',
            '/api/v1/admin/webhooks/deadletters',
          ]),
        ),
      );

      await tester.tap(find.text('Replay'));
      await tester.pumpAndSettle();
      await tester.enterText(_dialogField(), 'msg-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay').last);
      await tester.pumpAndSettle();

      expect(replayed, ['/api/v1/admin/webhooks/deadletters/msg-1/replay']);
      // Pending cleanup must be reported honestly, not as full success.
      expect(find.textContaining('cleanup remains pending'), findsOneWidget);
    });

    testWidgets('fails closed without capabilities', (tester) async {
      await _pump(tester, WebhooksTab(api: _api({}), capabilities: _caps([])));
      expect(
        find.text('Webhook management is not enabled on this replica.'),
        findsOneWidget,
      );
    });
  });

  group('CredentialsTab', () {
    testWidgets('lists credentials and reports a compromise', (tester) async {
      var compromised = <String>[];
      final api = _api({
        '/api/v1/admin/credentials': (_) => http.Response(
          jsonEncode({
            'credentials': [
              {'id': 'client-secrets', 'status': 'active'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/credentials/client-secrets/compromise': (request) {
          compromised.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await _pump(
        tester,
        CredentialsTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/credentials']),
        ),
      );

      expect(find.textContaining('client-secrets'), findsOneWidget);
      // The report form opens through the /credentials/report route.
      await tester.tap(find.text('Report compromise'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Credential type'),
        'client-secrets',
      );
      // Submit the form; the typed confirmation dialog opens.
      await tester.tap(find.text('Report compromise').last);
      await tester.pumpAndSettle();
      await tester.enterText(_dialogField(), 'client-secrets');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report').last);
      await tester.pumpAndSettle();

      expect(compromised, [
        '/api/v1/admin/credentials/client-secrets/compromise',
      ]);
    });

    testWidgets('requires a type before reporting', (tester) async {
      final api = _api({
        '/api/v1/admin/credentials': (_) =>
            http.Response(jsonEncode({'credentials': []}), 200),
      });
      await _pump(
        tester,
        CredentialsTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/credentials']),
        ),
      );

      await tester.tap(find.text('Report compromise'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report compromise').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter a credential type.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('CryptoKeysTab', () {
    testWidgets('lists keys and rotates the signing key', (tester) async {
      var rotated = 0;
      final api = _api({
        '/api/v1/admin/crypto/keys': (_) => http.Response(
          jsonEncode({
            'keys': [
              {'id': 'key-1', 'key_class': 'signing', 'status': 'active'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/keys/rotate': (request) {
          rotated++;
          return http.Response(
            jsonEncode({'key_class': 'signing', 'status': 'rollout'}),
            200,
          );
        },
      });
      await _pump(
        tester,
        CryptoKeysTab(
          api: api,
          capabilities: SnaplinkAdminCapabilities([
            SnaplinkAdminEndpoint(
              method: 'GET',
              path: '/api/v1/admin/crypto/keys',
              feature: 'core',
            ),
            SnaplinkAdminEndpoint(
              method: 'POST',
              path: '/api/v1/admin/keys/rotate',
              feature: 'core',
            ),
          ]),
        ),
      );

      expect(find.textContaining('key-1'), findsOneWidget);
      await tester.tap(find.text('Rotate signing key'));
      await tester.pumpAndSettle();
      expect(find.text('Rotate signing key?'), findsOneWidget);
      await tester.enterText(_dialogField(), 'ROTATE SIGNING KEY');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotate').last);
      await tester.pumpAndSettle();
      expect(rotated, 1);
    });
  });

  group('DomainsTab', () {
    testWidgets('lists domains and deletes one with confirmation', (
      tester,
    ) async {
      var deleted = <String>[];
      final api = _api({
        '/api/v1/admin/domains': (_) => http.Response(
          jsonEncode({
            'domains': [
              {'hostname': 'login.example.com', 'status': 'verified'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/domains/login.example.com': (request) {
          if (request.method == 'DELETE') deleted.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await _pump(
        tester,
        DomainsTab(api: api, capabilities: _caps(['/api/v1/admin/domains'])),
      );

      expect(find.text('login.example.com'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.enterText(_dialogField(), 'login.example.com');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(deleted, ['/api/v1/admin/domains/login.example.com']);
    });
  });

  group('DRModeTab', () {
    testWidgets('loads current mode and applies a degraded mode', (
      tester,
    ) async {
      var posted = <String>[];
      final api = _api({
        '/api/v1/admin/dr/mode': (request) {
          if (request.method == 'POST') {
            posted.add(request.body);
            return http.Response('{}', 200);
          }
          return http.Response(jsonEncode({'mode': 'normal'}), 200);
        },
      });
      await _pump(
        tester,
        DRModeTab(api: api, capabilities: _caps(['/api/v1/admin/dr/mode'])),
      );

      // Pick the read-only mode from the dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('read_only').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Reason / incident reference'),
        'INC-123',
      );
      await tester.tap(find.text('Apply service mode'));
      await tester.pumpAndSettle();
      // Type-to-confirm requires the mode name.
      await tester.enterText(_dialogField(), 'read_only');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply mode').last);
      await tester.pumpAndSettle();

      expect(posted.single, contains('"mode":"read_only"'));
      expect(posted.single, contains('"reason":"INC-123"'));
    });

    testWidgets('requires a reason before degrading', (tester) async {
      final api = _api({
        '/api/v1/admin/dr/mode': (_) =>
            http.Response(jsonEncode({'mode': 'normal'}), 200),
      });
      await _pump(
        tester,
        DRModeTab(api: api, capabilities: _caps(['/api/v1/admin/dr/mode'])),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('read_only').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply service mode'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Add an incident or change reference'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('ThreatPoliciesTab', () {
    testWidgets('lists policies and deletes one', (tester) async {
      var deleted = <String>[];
      final api = _api({
        '/api/v1/admin/threat-policies': (_) => http.Response(
          jsonEncode({
            'policies': [
              {'name': 'block-ip-reputation', 'action': 'block'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/threat-policies/block-ip-reputation': (request) {
          if (request.method == 'DELETE') deleted.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await _pump(
        tester,
        ThreatPoliciesTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/threat-policies']),
        ),
      );

      expect(find.text('block-ip-reputation'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.enterText(_dialogField(), 'block-ip-reputation');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(deleted, ['/api/v1/admin/threat-policies/block-ip-reputation']);
    });
  });

  group('TokenPoliciesTab', () {
    testWidgets('loads policies on refresh', (tester) async {
      final api = _api({
        '/api/v1/admin/token-policies': (_) => http.Response(
          jsonEncode({
            'policies': [
              {'id': 'access-lifetime', 'max_lifetime_seconds': 3600},
            ],
          }),
          200,
        ),
      });
      await _pump(
        tester,
        TokenPoliciesTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/token-policies']),
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(find.text('access-lifetime'), findsOneWidget);
    });
  });

  group('TokenExchangeTab', () {
    testWidgets('traces an exchange chain for a token', (tester) async {
      var traced = <String>[];
      final api = _api({
        '/api/v1/admin/tokenexchange/chains/tok-1': (request) {
          traced.add(request.url.path);
          return http.Response(
            jsonEncode({
              'chain': [
                {
                  'actor': 'client-a',
                  'source_jti': 'tok-1',
                  'target_jti': 'tok-2',
                },
              ],
            }),
            200,
          );
        },
      });
      await _pump(
        tester,
        TokenExchangeTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/tokenexchange']),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Token ID (JTI)'),
        'tok-1',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(traced, ['/api/v1/admin/tokenexchange/chains/tok-1']);
      expect(find.text('client-a'), findsOneWidget);
      expect(find.text('tok-2'), findsOneWidget);
    });

    testWidgets('requires a token id before tracing', (tester) async {
      final api = _api({
        '/api/v1/admin/tokenexchange/chains/x': (_) =>
            http.Response(jsonEncode({'chain': []}), 200),
      });
      await _pump(
        tester,
        TokenExchangeTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/tokenexchange']),
        ),
      );

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('Enter a token ID (jti).'), findsOneWidget);
    });
  });
}
