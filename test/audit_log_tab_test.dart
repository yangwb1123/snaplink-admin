import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/screens/admin/audit_log_tab.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/local_storage.dart';

const _eventsBody =
    '{"events":['
    '{"id":"e-1","type":"admin_client_created","outcome":"success",'
    '"timestamp":"2026-08-05T12:00:00Z","actor_id":"admin-1",'
    '"client_id":"console","tenant_id":"acme"},'
    '{"id":"e-2","type":"admin_user_deleted","outcome":"failure",'
    '"timestamp":"2026-08-05T13:00:00Z","actor_id":"admin-2",'
    '"client_id":"console","tenant_id":"acme"}],'
    '"count":999}';

/// Seeds three server rows at the given timestamps — one per relative
/// bucket (just-now / m-ago / h-ago) for the TIME column wiring tests.
String _eventsBodyRelative(DateTime a, DateTime b, DateTime c) =>
    '{"events":['
    '{"id":"e-1","type":"admin_client_created","outcome":"success",'
    '"timestamp":"${a.toUtc().toIso8601String()}","actor_id":"admin-1",'
    '"client_id":"console","tenant_id":"acme"},'
    '{"id":"e-2","type":"admin_user_deleted","outcome":"failure",'
    '"timestamp":"${b.toUtc().toIso8601String()}","actor_id":"admin-2",'
    '"client_id":"console","tenant_id":"acme"},'
    '{"id":"e-3","type":"admin_role_created","outcome":"success",'
    '"timestamp":"${c.toUtc().toIso8601String()}","actor_id":"admin-1",'
    '"client_id":"console","tenant_id":"acme"}],'
    '"count":999}';

String? _clipboardText;

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

/// Recording MockClient: records path + queryParameters for every request.
SnaplinkAdminApi _recordingApi(
  List<Uri> requests,
  Map<String, http.Response Function(http.Request)> routes,
) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    requests.add(request.url);
    final handler = routes[request.url.path];
    if (handler != null) return handler(request);
    return http.Response('{"error":"not found"}', 404);
  }),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

Future<void> _pumpZh(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppSettings.supportedLocales,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void _seedForgedRing() {
  final service = AuditLogService();
  addTearDown(service.clear);
  service.record(
    AuditEntry(
      timestamp: DateTime.now(),
      method: 'POST',
      path: '/api/v1/admin/forged',
      statusCode: 200,
      label: 'forged entry',
    ),
  );
}

/// T-12 raw-devtools seeding variant (REQ-3 R3.2): plants the forged row
/// via a direct `LocalStorage.setItem` BEFORE the page pump — a
/// devtools-forged payload, not `AuditLogService().record` (that is
/// `_seedForgedRing`'s job for AC-1.5). The tab must never render it,
/// and (off polarity) must leave it byte-identical: display truth comes
/// exclusively from AuditReadClient `/api/v1/audit/events` (F7).
/// Unconditional teardown removes the seeded key and restores the flag
/// (FD-S3 — later tests in this isolate must not observe either).
/// R5.3 dependency: this joint is conditioned on the landed server-fed
/// timeline (direction 1); if that read path is reverted, this check is
/// blocked, never silently green.
void _seedForgedRingRaw() {
  LocalStorage.setItem(
    'sso_audit_log',
    jsonEncode([
      {
        'timestamp': DateTime.now().toIso8601String(),
        'method': 'POST',
        'path': '/api/v1/admin/forged',
        'statusCode': 200,
        'label': 'forged entry',
      },
    ]),
  );
  addTearDown(() => LocalStorage.removeItem('sso_audit_log'));
}

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('AuditLogTab server read (AC-1 / AC-3)', () {
    testWidgets(
      'issues exactly one events request with {limit: 100}, renders server '
      'rows, never the response count, and ignores the ring',
      (tester) async {
        _seedForgedRing();
        final requests = <Uri>[];
        final api = _recordingApi(requests, {
          '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
        });
        await _pump(
          tester,
          AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
        );

        // AC-1.2: exactly one request to events, exact query, zero others.
        expect(requests, hasLength(1));
        final uri = requests.single;
        expect(uri.path, '/api/v1/audit/events');
        expect(uri.queryParameters, {'limit': '100'});
        expect(uri.queryParameters.containsKey('tenant_id'), isFalse);
        expect(uri.queryParameters.containsKey('trace_id'), isFalse);

        // AC-1.4: rows render from the server response; the planted decoy
        // count (999) is never read — the header shows the page size.
        expect(find.text('2 entries'), findsOneWidget);
        expect(find.textContaining('999'), findsNothing);
        expect(find.textContaining('admin_client_created'), findsOneWidget);
        expect(find.textContaining('admin_user_deleted'), findsOneWidget);
        expect(
          find.textContaining('on this device'),
          findsNothing,
          reason: 'subtitle must be server-sourced',
        );

        // AC-1.5: the seeded ring entry is not evidence.
        expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
        expect(find.textContaining('forged entry'), findsNothing);

        // AC-1.6: search re-queries with the identical exact query.
        await tester.enterText(find.byType(TextField), 'admin_client');
        await tester.pumpAndSettle();
        expect(requests, hasLength(2));
        for (final request in requests) {
          expect(request.queryParameters, {'limit': '100'});
        }
        expect(find.textContaining('admin_client_created'), findsOneWidget);
        expect(find.textContaining('admin_user_deleted'), findsNothing);
      },
    );

    testWidgets('zh locale: count and subtitle render translated copy', (
      tester,
    ) async {
      // Clipboard mock for the CSV snackbar exact-key pin.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            _clipboardText = args['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return _clipboardText == null ? null : {'text': _clipboardText};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppSettings.supportedLocales,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: AuditLogTab(
              api: api,
              capabilities: _caps(['/api/v1/audit/events']),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('共 2 条'), findsOneWidget);
      expect(find.text('服务器记录的全部认证与管理事件。'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      // The outcome filter items render only when the dropdown is open.
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('成功'), findsOneWidget);
      expect(find.text('失败'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // CSV snackbar resolves through the exact-key path (args form) in zh
      // — the pre-interpolated form would only work via the fragile
      // pattern fallback.
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('已将 2 条记录以 CSV 导出到剪贴板'), findsOneWidget);
      expect(find.textContaining('Exported 2 entries as CSV'), findsNothing);
    });

    testWidgets(
      'F5 regression: authorization query values are scrubbed in the EVENT '
      'column and never ride the CSV clipboard export',
      (tester) async {
        _clipboardText = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<Object?, Object?>;
              _clipboardText = args['text'] as String?;
              return null;
            }
            if (call.method == 'Clipboard.getData') {
              return _clipboardText == null ? null : {'text': _clipboardText};
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final api = _api({
          '/api/v1/audit/events': (_) => http.Response(
            '{"events":['
            '{"id":"e-1","type":"https://sso.example.test/oauth/authorize'
            '?code=C0DESECRET&state=ST8SECRET&jwt=J0TSECRET'
            '&limit=100&tenant_id=acme","outcome":"failure",'
            '"timestamp":"2026-08-05T12:00:00Z"}],"count":1}',
            200,
          ),
        });
        await _pump(
          tester,
          AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
        );

        // The EVENT column renders the scrubbed URI: secrets gone, audit
        // context (limit/tenant_id) and the param keys retained.
        for (final secret in const ['C0DESECRET', 'ST8SECRET', 'J0TSECRET']) {
          expect(find.textContaining(secret), findsNothing);
        }
        expect(find.textContaining('%3Credacted%3E'), findsOneWidget);
        expect(find.textContaining('limit=100'), findsOneWidget);

        // The CSV clipboard export rides the same scrubbed row: no secret
        // value in any cell, redacted marker present, context preserved.
        await tester.tap(find.byIcon(Icons.file_download_outlined));
        await tester.pumpAndSettle();
        expect(_clipboardText, isNotNull);
        expect(_clipboardText, isNot(contains('C0DESECRET')));
        expect(_clipboardText, isNot(contains('ST8SECRET')));
        expect(_clipboardText, isNot(contains('J0TSECRET')));
        expect(_clipboardText, contains('%3Credacted%3E'));
        expect(_clipboardText, contains('limit=100'));
        expect(_clipboardText, contains('tenant_id=acme'));
      },
    );

    testWidgets('AC-3a: server success renders the served page size', (
      tester,
    ) async {
      _seedForgedRing();
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(find.text('2 entries'), findsOneWidget);
      expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
      expect(find.textContaining('forged entry'), findsNothing);
      // Error-rate badge from server rows: one failure of two → 50%.
      expect(find.textContaining('50% errors'), findsOneWidget);
    });

    testWidgets('AC-3b: server 500 → error state + retry; ring still inert', (
      tester,
    ) async {
      _seedForgedRing();
      final requests = <Uri>[];
      final api = _recordingApi(requests, {
        '/api/v1/audit/events': (_) => http.Response(
          jsonEncode({
            'error': 'internal_error',
            'message': 'Query failed',
            'details': [
              {
                'metadata': {'operation_id': 'op-1', 'event': 'secret'},
              },
            ],
          }),
          500,
        ),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(find.text('Query failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
      expect(find.textContaining('forged entry'), findsNothing);
      // error.data bait never surfaces.
      expect(find.textContaining('op-1'), findsNothing);
      expect(find.textContaining('secret'), findsNothing);

      // Retry re-enters the gate and issues a fresh request.
      final before = requests.length;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(requests.length, greaterThan(before));
    });

    testWidgets('AC-3c: empty server result → 0 entries + server-truth empty', (
      tester,
    ) async {
      _seedForgedRing();
      final api = _api({
        '/api/v1/audit/events': (_) =>
            http.Response('{"events": [], "count": 0}', 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(find.text('0 entries'), findsOneWidget);
      expect(
        find.text('No audit events returned by the server yet.'),
        findsOneWidget,
      );
      expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
      expect(find.textContaining('forged entry'), findsNothing);
    });

    testWidgets('AC-4.1: trio-less capabilities → not-enabled, zero requests', (
      tester,
    ) async {
      final requests = <Uri>[];
      final api = _recordingApi(requests, {});
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/admin/endpoints'])),
      );

      expect(
        find.text('This feature is not enabled on the connected replica.'),
        findsOneWidget,
      );
      expect(requests, isEmpty);
    });

    testWidgets('AC-4.2: positive capabilities → exactly one request + rows', (
      tester,
    ) async {
      final requests = <Uri>[];
      final api = _recordingApi(requests, {
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(requests, hasLength(1));
      expect(requests.single.path, '/api/v1/audit/events');
      expect(find.text('2 entries'), findsOneWidget);
    });

    testWidgets(
      'present-branch: injected tenantId/traceId ride the wire (REQ-2)',
      (tester) async {
        _seedForgedRing();
        final requests = <Uri>[];
        final api = _recordingApi(requests, {
          '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
        });
        await _pump(
          tester,
          AuditLogTab(
            api: api,
            capabilities: _caps(['/api/v1/audit/events']),
            tenantId: 'acme',
            traceId: 'tr-1',
          ),
        );

        // Exactly one request to the trio events path; the injected seam
        // values ride the wire verbatim alongside the default page size.
        expect(requests, hasLength(1));
        final uri = requests.single;
        expect(uri.path, '/api/v1/audit/events');
        expect(uri.queryParameters, {
          'limit': '100',
          'tenant_id': 'acme',
          'trace_id': 'tr-1',
        });
        // Rows come from the mock body; no /facets, no /events/{id}
        // requests, no forged ring on the render path.
        expect(find.text('2 entries'), findsOneWidget);
        expect(find.textContaining('admin_client_created'), findsOneWidget);
        expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
        expect(find.textContaining('forged entry'), findsNothing);

        // Trim semantics corner: whitespace-padded seam values are
        // trimmed by AuditQuery before serialization. Pump a placeholder
        // first so the same-slot widget cannot reuse the previous state
        // (initState must re-run with the new seam values).
        requests.clear();
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          AuditLogTab(
            api: api,
            capabilities: _caps(['/api/v1/audit/events']),
            tenantId: '  acme  ',
            traceId: ' tr-1 ',
          ),
        );
        expect(requests, hasLength(1));
        expect(requests.single.queryParameters, {
          'limit': '100',
          'tenant_id': 'acme',
          'trace_id': 'tr-1',
        });
      },
    );
  });

  group('FM-2 / FM-3 / FM-7 error-state variants', () {
    testWidgets('FM-2: transport timeout after retries → same error state, '
        'no ring fallback', (tester) async {
      _seedForgedRing();
      final held = Completer<http.Response>();
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((request) => held.future),
      );
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditLogTab(
              api: api,
              capabilities: _caps(['/api/v1/audit/events']),
            ),
          ),
        ),
      );
      // Explicit pump only — never pumpAndSettle while a request is
      // held (FM-9 idiom).
      await tester.pump();
      held.completeError(TimeoutException('Timed out'));
      // Load-bearing: the transport retries the GET 3× (1000ms, then
      // 2000ms backoff — pow(2, attempt) * 500, snaplink_admin_api.dart)
      // before the raw TimeoutException reaches the tab's
      // `on TimeoutException` branch. pumpAndSettle alone cannot advance
      // a Future.delayed timer that has not scheduled a frame — advance
      // the fake clock explicitly past both delays.
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pumpAndSettle();
      // Same error state as AC-3b — and never a ring fallback.
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Timed out'), findsOneWidget);
      expect(find.textContaining('admin_client_created'), findsNothing);
      expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
      expect(find.textContaining('forged entry'), findsNothing);
    });

    testWidgets('FM-3: server 401 → description in the same error state; the '
        'session hook still fires', (tester) async {
      _seedForgedRing();
      var unauthorizedFired = false;
      final requests = <Uri>[];
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        onUnauthorized: () => unauthorizedFired = true,
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'error': 'unauthorized',
              'message': 'Session expired. Please sign in again.',
            }),
            401,
          );
        }),
      );
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      // The transport hook fires through the tab's read path — never
      // swallowed or reimplemented by the tab.
      expect(unauthorizedFired, isTrue);
      // The 401 description renders via the shared error state;
      // error.code ('unauthorized') is never the rendered text
      // (SnaplinkAdminApiError.toString() = description ?? code ?? …).
      expect(
        find.text('Session expired. Please sign in again.'),
        findsOneWidget,
      );
      expect(find.textContaining('unauthorized'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('admin_client_created'), findsNothing);
      expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
      expect(find.textContaining('forged entry'), findsNothing);
      // Retry re-enters the gate and issues a fresh request after a 401.
      final before = requests.length;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(requests.length, greaterThan(before));
    });

    testWidgets(
      'FM-7: malformed envelope → server-truth empty state, no crash, '
      'no fabricated rows',
      (tester) async {
        _seedForgedRing();
        final api = _api({
          '/api/v1/audit/events': (_) => http.Response(
            '{"events": {"id": "not-a-list"}, "count": 999}',
            200,
          ),
        });
        await _pump(
          tester,
          AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
        );

        // Wrong-typed `events` maps to zero rows (mapper never throws) —
        // the widget shows the server-truth empty state, NOT the error
        // state: no Retry, no crash, and the decoy count 999 / forged ring
        // never render.
        expect(find.text('0 entries'), findsOneWidget);
        expect(
          find.text('No audit events returned by the server yet.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
        expect(find.textContaining('999'), findsNothing);
        expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
        expect(find.textContaining('forged entry'), findsNothing);
      },
    );
  });

  group('FM-9 stale-response race', () {
    testWidgets('older in-flight response never replaces newer rows', (
      tester,
    ) async {
      final first = Completer<http.Response>();
      final second = Completer<http.Response>();
      var calls = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((request) {
          calls++;
          if (calls == 1) return first.future;
          return second.future;
        }),
      );
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditLogTab(
              api: api,
              capabilities: _caps(['/api/v1/audit/events']),
            ),
          ),
        ),
      );
      // Request 1 (older) is in flight; explicit pump only — never
      // pumpAndSettle while a request is held.
      await tester.pump();

      // Trigger the second (newer) request via search onChanged — the
      // refresh button is disabled while loading. The search term matches
      // both row types so the stale guard, not the filter, decides what
      // renders.
      await tester.enterText(find.byType(TextField), 'event');
      await tester.pump();

      http.Response body(String type) => http.Response(
        jsonEncode({
          'events': [
            {
              'id': type == 'newer' ? 'n-1' : 'o-1',
              'type': type,
              'outcome': 'success',
              'timestamp': '2026-08-05T12:00:00Z',
            },
          ],
        }),
        200,
      );

      // Complete the NEWER response first, then the OLDER one.
      second.complete(body('newer-event'));
      await tester.pump();
      first.complete(body('older-event'));
      await tester.pumpAndSettle();

      expect(find.text('1 entries'), findsOneWidget);
      expect(find.textContaining('newer-event'), findsOneWidget);
      expect(find.textContaining('older-event'), findsNothing);
    });
  });

  // B6-1b — debug-only ring copy surface (AC-1/AC-2/AC-3).
  // Harness facts: `_seedForgedRing` records exactly ONE ring entry,
  // `_eventsBody` serves TWO rows with a `count: 999` decoy — ring=1,
  // rows=2, decoy=999 — so every marker/dialog pin uses 1, not 2
  // (reseeding to 2 would make the marker-vs-header pin vacuous).
  group('B6-1b debug ring copy surface (AC-1 / AC-2 / AC-3)', () {
    setUp(() => AuditLogService.debugRingEnabled = true);

    test('AC-1: the five B6-1b keys resolve zh atomically', () {
      final zh = AppStrings.forLocale(const Locale('zh'));
      const expected = <String, String>{
        'Clear local debug records?': '清除本地调试记录？',
        'This will permanently delete all {n} local debug records.':
            '这将永久删除全部 {n} 条本地调试记录。',
        'Clear local debug records': '清除本地调试记录',
        'Debug records: {n} entries': '调试记录：共 {n} 条',
        'Debug records': '本地调试记录',
      };
      expected.forEach((key, value) {
        expect(
          zh.translate(key),
          isNot(key),
          reason: '$key must resolve zh, not fall back to English',
        );
        expect(zh.translate(key), value, reason: 'exact zh for $key');
      });
    });

    testWidgets(
      '2a: marker renders with the ring count, never the server count',
      (tester) async {
        _seedForgedRing();
        final api = _api({
          '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
        });
        await _pump(
          tester,
          AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
        );

        expect(find.text('Debug records'), findsOneWidget);
        // Ring count (1) in the debug badge only — header stays server
        // truth (2 rows), decoy 999 never rendered.
        expect(find.text('Debug records: 1 entries'), findsOneWidget);
        expect(find.text('2 entries'), findsOneWidget);
        expect(find.textContaining('999'), findsNothing);
      },
    );

    testWidgets('2a: flag off hides marker and delete icon', (tester) async {
      AuditLogService.debugRingEnabled = false;
      addTearDown(() => AuditLogService.debugRingEnabled = true);
      _seedForgedRing();
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(find.text('Debug records'), findsNothing);
      expect(find.text('Debug records: 1 entries'), findsNothing);
      expect(find.byIcon(Icons.delete_sweep), findsNothing);
      // Server truth unaffected.
      expect(find.text('2 entries'), findsOneWidget);
    });

    testWidgets(
      '2b: Clear dialog uses ring-scoped copy; confirm clears the ring only',
      (tester) async {
        _seedForgedRing();
        final api = _api({
          '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
        });
        await _pump(
          tester,
          AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
        );

        await tester.tap(find.byIcon(Icons.delete_sweep));
        await tester.pumpAndSettle();
        expect(find.text('Clear local debug records?'), findsOneWidget);
        // N = seeded ring count (1), not the served page size.
        expect(
          find.text('This will permanently delete all 1 local debug records.'),
          findsOneWidget,
        );
        expect(find.text('Clear local debug records').last, findsOneWidget);
        // Old ring-scoped keys are gone entirely.
        expect(find.text('Clear audit log?'), findsNothing);
        expect(find.text('Clear log'), findsNothing);

        await tester.tap(find.text('Clear local debug records').last);
        await tester.pumpAndSettle();
        expect(AuditLogService().count, 0);
        // Server rows untouched by the ring clear.
        expect(find.text('2 entries'), findsOneWidget);
      },
    );

    testWidgets('2c: flag off hides the Clear action', (tester) async {
      AuditLogService.debugRingEnabled = false;
      addTearDown(() => AuditLogService.debugRingEnabled = true);
      _seedForgedRing();
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(find.byIcon(Icons.delete_sweep), findsNothing);
      expect(find.text('Clear local debug records?'), findsNothing);
    });

    testWidgets('2e: zh locale — marker and Clear dialog resolve exact keys', (
      tester,
    ) async {
      _seedForgedRing();
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      await _pumpZh(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(find.text('本地调试记录'), findsOneWidget);
      expect(find.text('调试记录：共 1 条'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();
      expect(find.text('清除本地调试记录？'), findsOneWidget);
      // Exact-key + args zh path — the old key's rendered output is
      // absent (调试 interrupts 本地|审计, so the needle is sound).
      expect(find.text('这将永久删除全部 1 条本地调试记录。'), findsOneWidget);
      expect(find.textContaining('这将永久删除全部 1 条本地审计记录。'), findsNothing);
      expect(find.text('清除本地调试记录'), findsOneWidget);
    });

    testWidgets('AC-3 joint: empty server (rows=0) vs ring=1 — badge only', (
      tester,
    ) async {
      _seedForgedRing();
      final api = _api({
        '/api/v1/audit/events': (_) =>
            http.Response('{"events": [], "count": 0}', 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      // The only configuration where ring-vs-server-vs-decoy are pairwise
      // distinguishable on the marker: ring count lives in the badge,
      // never in the header count.
      expect(find.text('Debug records: 1 entries'), findsOneWidget);
      expect(find.text('0 entries'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
    });

    testWidgets('AC-1: zh TIME column renders the three relative forms', (
      tester,
    ) async {
      // Seeds at now−30s / now−5min / now−2h — one row per relative bucket,
      // so every _formatTime branch is behaviorally pinned (FM-7 margins:
      // just-now holds for <30s of seed→build latency, inMinutes==5 for
      // <60s, inHours==2 for <60min). tester.pump(duration) advances the
      // fake clock, not DateTime.now(), so only real wall-clock matters.
      final now = DateTime.now();
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(
          _eventsBodyRelative(
            now.subtract(const Duration(seconds: 30)),
            now.subtract(const Duration(minutes: 5)),
            now.subtract(const Duration(hours: 2)),
          ),
          200,
        ),
      });
      await _pumpZh(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      // Exact-key + args zh path: 'just now' direct-key, '{count}m ago' and
      // '{count}h ago' with {'count': int} — never English relative labels.
      expect(find.text('刚刚'), findsOneWidget);
      expect(find.text('5 分钟前'), findsOneWidget);
      expect(find.text('2 小时前'), findsOneWidget);
      expect(find.textContaining('m ago'), findsNothing);
      expect(find.textContaining('h ago'), findsNothing);
      expect(find.textContaining('just now'), findsNothing);
    });

    testWidgets('AC-1b: en TIME column passthrough stays byte-identical', (
      tester,
    ) async {
      // en short-circuit (translate returns source verbatim) — first en
      // time pins in this file; closes the h-ago branch statically.
      final now = DateTime.now();
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(
          _eventsBodyRelative(
            now.subtract(const Duration(seconds: 30)),
            now.subtract(const Duration(minutes: 5)),
            now.subtract(const Duration(hours: 2)),
          ),
          200,
        ),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(find.text('just now'), findsOneWidget);
      expect(find.text('5m ago'), findsOneWidget);
      expect(find.text('2h ago'), findsOneWidget);
    });

    testWidgets('T-12 raw-devtools seeding — on polarity: forged rows '
        'never render; server truth does', (tester) async {
      // R3.2 on polarity: storage axis at its default (on in test
      // builds) — nothing to set. The forged payload is planted raw,
      // bypassing the service entirely.
      _seedForgedRingRaw();
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      // Negative: the devtools-forged row is not evidence.
      expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
      expect(find.textContaining('forged entry'), findsNothing);
      // Positive control (FD-S2): server rows render, so the test is
      // live — the negatives are not vacuous.
      expect(find.textContaining('admin_client_created'), findsOneWidget);
      expect(find.textContaining('admin_user_deleted'), findsOneWidget);
    });

    testWidgets('T-12 raw-devtools seeding — off polarity: forged rows '
        'never render AND the payload stays byte-identical', (tester) async {
      // R3.2 off polarity: storage off simulates release — the tab must
      // neither read nor write the ring, and the app must never remove
      // the key (rule (e)).
      AuditLogService.debugStorageEnabled = false;
      addTearDown(() => AuditLogService.debugStorageEnabled = true);
      _seedForgedRingRaw();
      final seeded = LocalStorage.getItem('sso_audit_log');
      expect(seeded, isNotNull);

      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
      expect(find.textContaining('forged entry'), findsNothing);
      // Positive control (FD-S2).
      expect(find.textContaining('admin_client_created'), findsOneWidget);
      // FD-S4: the raw payload is byte-identical after the pump — the
      // tab never wrote the ring, and no lib/ code removed the key.
      expect(LocalStorage.getItem('sso_audit_log'), seeded);
    });
  });
}
