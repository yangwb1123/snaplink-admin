@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/audit_log_tab.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/local_storage.dart';

/// AC-3 forge-invisibility guard (spec REQ-3, T-12 joint; design §1.2).
///
/// The server-fed timeline (landed B6-1a `AuditLogTab`) renders server rows
/// only. A pre-seeded forged ring entry whose vocabulary MATCHES a server
/// row (forged label == a server row's `type`, path naming the same
/// resource — the dedup/misattribution variant the landed admin joints
/// leave unpinned) must never render as a row, never merge with or
/// duplicate the server row (`findsOneWidget`, never `findsNWidgets(2)`),
/// never appear as fallback content, and never be written to by the
/// timeline itself.
///
/// Harness is a private copy of the landed `audit_log_tab_test.dart`
/// helpers (deliberate duplication, design C9 — the deliverable stays
/// self-contained at three files).
const _eventsBody =
    '{"events":['
    '{"id":"e-1","type":"admin_client_created","outcome":"success",'
    '"timestamp":"2026-08-05T12:00:00Z","actor_id":"admin-1",'
    '"client_id":"console","tenant_id":"acme"},'
    '{"id":"e-2","type":"admin_user_deleted","outcome":"failure",'
    '"timestamp":"2026-08-05T13:00:00Z","actor_id":"admin-2",'
    '"client_id":"console","tenant_id":"acme"}],'
    '"count":2}';

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

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'matching-vocabulary forged ring entry never renders as evidence (AC-3)',
    (tester) async {
      // Pre-seed the ring with a forged entry whose label matches a server
      // row type and whose path names the same resource (spec AC-3.1).
      AuditLogService().record(
        AuditEntry(
          timestamp: DateTime.now(),
          method: 'POST',
          path: '/api/v1/admin/clients',
          statusCode: 200,
          label: 'admin_client_created',
        ),
      );
      addTearDown(AuditLogService().clear);

      // Post-seed snapshots + seed sanity.
      final keysBefore = LocalStorage.keys().toSet();
      final valueBefore = LocalStorage.getItem('sso_audit_log');
      final countBefore = AuditLogService().count;
      expect(keysBefore, contains('sso_audit_log'), reason: 'seed sanity');
      expect(countBefore, 1, reason: 'seed sanity');

      // Pump the landed server-fed timeline (spec AC-3.2): exactly two
      // server rows (design V2 — the header count is `_rows.length`, never
      // the wire count and never the ring).
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(_eventsBody, 200),
      });
      await _pump(
        tester,
        AuditLogTab(api: api, capabilities: _caps(['/api/v1/audit/events'])),
      );

      // T-12 joint (spec AC-3.3, REQ-3).
      expect(
        find.textContaining('admin_client_created'),
        findsOneWidget,
        reason:
            'server row renders exactly once; the forged duplicate never merges',
      );
      expect(
        find.textContaining('/api/v1/admin/clients'),
        findsNothing,
        reason:
            'FUTURE-PIN (non-current-behavior): no path column renders today — '
            'trips when a future commit renders ring paths',
      );
      expect(
        find.textContaining('forged'),
        findsNothing,
        reason: 'forged entries never render as evidence',
      );
      expect(
        find.text('2 entries'),
        findsOneWidget,
        reason:
            'header count derives from _rows.length (2 rows), never the wire '
            'count or the ring',
      );

      // Post-pump ring hygiene (design V6): the timeline must not write.
      expect(
        LocalStorage.keys().toSet(),
        keysBefore,
        reason: 'the timeline must not write to the ring',
      );
      expect(
        LocalStorage.getItem('sso_audit_log'),
        valueBefore,
        reason: 'the timeline must not rewrite the ring value',
      );
      expect(
        AuditLogService().count,
        countBefore,
        reason: 'the timeline must not append ring entries',
      );
    },
  );
}
