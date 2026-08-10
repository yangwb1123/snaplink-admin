import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/admin_overview_tab.dart';
import 'package:sso_admin/screens/admin/audit_log_tab.dart';
import 'package:sso_admin/screens/admin/client_detail_screen.dart';
import 'package:sso_admin/screens/admin/clients_tab.dart';
import 'package:sso_admin/screens/admin/tenant_detail_screen.dart';
import 'package:sso_admin/screens/admin/tenants_tab.dart';
import 'package:sso_admin/screens/admin/user_detail_screen.dart';
import 'package:sso_admin/screens/admin/users_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/status_chip.dart';

/// Wave-1 page wiring tests (design §4.1–§4.8; T-W1-01..09).
MockClient _mock(Map<String, http.Response Function(http.Request)> routes) =>
    MockClient((request) async {
      final handler = routes[request.url.path];
      if (handler != null) return handler(request);
      return http.Response('{"error":"not found"}', 404);
    });

SSOAdminClient _sso(Map<String, http.Response Function(http.Request)> routes) =>
    SSOAdminClient('https://sso.example.test', httpClient: _mock(routes));

SnaplinkAdminApi _api(
  Map<String, http.Response Function(http.Request)> routes,
) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: _mock(routes),
);

SnaplinkAdminCapabilities _caps(List<String> paths) =>
    SnaplinkAdminCapabilities([
      for (final path in paths)
        SnaplinkAdminEndpoint(method: 'GET', path: path, feature: 'core'),
    ]);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _pumpWide(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(child));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('T-W1-01/02: overview', () {
    const endpoints = [
      SnaplinkAdminEndpoint(
        method: 'GET',
        path: '/api/v1/admin/clients',
        feature: 'oauth',
      ),
      SnaplinkAdminEndpoint(
        method: 'GET',
        path: '/api/v1/admin/crypto/keys',
        feature: 'crypto',
      ),
      SnaplinkAdminEndpoint(
        method: 'GET',
        path: '/api/v1/admin/audit/events',
        feature: 'audit',
      ),
    ];

    Widget overview(OperatorPersona persona) => AdminOverviewTab(
      endpoints: endpoints,
      loadError: null,
      onRefresh: () {},
      persona: persona,
      commerceAvailable: true,
      commerceProbeError: null,
    );

    testWidgets(
      '01: securityOps — metrics, disclosure chip, bar, group order',
      (tester) async {
        await _pumpWide(tester, overview(OperatorPersona.securityOps));

        // Four real-value metric cards.
        expect(find.byType(KeyMetricCard), findsNWidgets(4));
        expect(find.byType(DistributionBar), findsOneWidget);

        // securityOps: documented-only metric leads the strip.
        final documented = tester.getTopLeft(
          find.text('Documented-only routes'),
        );
        final live = tester.getTopLeft(find.text('Live endpoints'));
        expect(documented.dx, lessThan(live.dx));

        // Persona disclosure chip + tooltip source.
        expect(
          find.textContaining('Persona: Persona.securityOps'),
          findsOneWidget,
        );

        // Group-card reorder: Security operations leads for securityOps.
        final security = tester.getTopLeft(find.text('Security operations'));
        final apps = tester.getTopLeft(find.text('Applications and OAuth'));
        expect(security.dy, lessThan(apps.dy));

        // Status card for securityOps shows the documented-only warning.
        expect(
          find.textContaining('documented routes not advertised'),
          findsOneWidget,
        );
      },
    );

    testWidgets('02: persona chip label follows the persona input', (
      tester,
    ) async {
      await _pumpWide(tester, overview(OperatorPersona.identityOps));
      expect(
        find.textContaining('Persona: Persona.identityOps'),
        findsOneWidget,
      );
    });

    testWidgets('01b: general keeps the data-natural order', (tester) async {
      await _pumpWide(tester, overview(OperatorPersona.general));
      final live = tester.getTopLeft(find.text('Live endpoints'));
      final documented = tester.getTopLeft(find.text('Documented-only routes'));
      expect(live.dx, lessThan(documented.dx));
      expect(find.textContaining('Persona: Persona.general'), findsOneWidget);
    });
  });

  group('T-W1-03: clients', () {
    const row = {
      'id': 'portal-client',
      'name': 'Portal client',
      'active': true,
      'tokenStrategy': 'opaque',
      'client_secret_expires_at': 0,
    };

    testWidgets('strip + distribution + noMatch/empty split', (tester) async {
      final client = _sso({
        '/api/v1/admin/clients': (request) {
          if (request.url.queryParameters['filter'] == 'zzz') {
            return http.Response(
              jsonEncode({'clients': <Object>[], 'total_size': 0}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'clients': [row],
              'total_size': 12,
            }),
            200,
          );
        },
      });
      await _pumpWide(tester, ClientsTab(client: client));

      // Strip: 4 cards + status distribution bar.
      expect(find.byType(KeyMetricCard), findsNWidgets(4));
      expect(find.byType(DistributionBar), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Active · 1'), findsOneWidget);
      // Zero-valued segment renders no legend entry (honesty rule).
      expect(find.textContaining('Inactive ·'), findsNothing);

      // Filter active → noMatch variant with the new pinned subtitle.
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('No clients match the current filter.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is EmptyState && w.variant == EmptyStateVariant.noMatch,
        ),
        findsOneWidget,
      );

      // No filter + empty result → empty variant with pinned copy.
      final emptyClient = _sso({
        '/api/v1/admin/clients': (_) => http.Response(
          jsonEncode({'clients': <Object>[], 'total_size': 0}),
          200,
        ),
      });
      await _pumpWide(
        tester,
        ClientsTab(key: const ValueKey('empty'), client: emptyClient),
      );
      expect(
        find.text('Create your first client to get started.'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is EmptyState && w.variant == EmptyStateVariant.empty,
        ),
        findsOneWidget,
      );
    });

    testWidgets('securityOps persona: Secrets expiring leads the strip', (
      tester,
    ) async {
      final client = _sso({
        '/api/v1/admin/clients': (_) => http.Response(
          jsonEncode({
            'clients': [row],
            'total_size': 1,
          }),
          200,
        ),
      });
      await _pumpWide(
        tester,
        ClientsTab(client: client, persona: OperatorPersona.securityOps),
      );
      final secrets = tester.getTopLeft(find.text('Secrets expiring'));
      final total = tester.getTopLeft(find.text('Total'));
      expect(secrets.dx, lessThan(total.dx));
    });
  });

  group('T-W1-04: users', () {
    testWidgets('providers metric + provider distribution', (tester) async {
      final client = _sso({
        '/api/v1/admin/users': (_) => http.Response(
          jsonEncode({
            'users': [
              {'id': 'user-1', 'provider': 'local'},
              {'id': 'user-2', 'provider': 'local'},
              {'id': 'user-3', 'provider': 'oidc'},
            ],
            'total_size': 3,
          }),
          200,
        ),
      });
      await _pumpWide(tester, UsersTab(client: client));

      expect(find.byType(KeyMetricCard), findsNWidgets(2));
      expect(find.text('Providers'), findsOneWidget);
      expect(find.text('local · 2'), findsOneWidget);
      expect(find.text('oidc · 1'), findsOneWidget);
      expect(find.byType(DistributionBar), findsOneWidget);
    });
  });

  group('T-W1-05: tenants', () {
    testWidgets('Active/Suspended strip + distribution', (tester) async {
      final client = _sso({
        '/api/v1/admin/tenants': (_) => http.Response(
          jsonEncode({
            'tenants': [
              {
                'id': 'tenant-a',
                'name': 'Acme',
                'slug': 'acme',
                'status': 'active',
              },
              {
                'id': 'tenant-b',
                'name': 'Globex',
                'slug': 'globex',
                'status': 'suspended',
              },
            ],
            'total_size': 2,
          }),
          200,
        ),
      });
      await _pumpWide(
        tester,
        TenantsTab(client: client, persona: OperatorPersona.identityOps),
      );

      expect(find.byType(KeyMetricCard), findsNWidgets(3));
      expect(find.text('Suspended'), findsWidgets);
      expect(find.text('Active · 1'), findsOneWidget);
      expect(find.text('Suspended · 1'), findsOneWidget);
      // identityOps: Active leads the strip.
      final active = tester.getTopLeft(find.text('Active').first);
      final total = tester.getTopLeft(find.text('Total'));
      expect(active.dx, lessThan(total.dx));
    });
  });

  group('T-W1-06: audit log', () {
    const eventsBody =
        '{"events":['
        '{"id":"e-1","type":"admin_client_created","outcome":"success",'
        '"timestamp":"2026-08-05T12:00:00Z","actor_id":"admin-1",'
        '"client_id":"console","tenant_id":"acme"},'
        '{"id":"e-2","type":"admin_user_deleted","outcome":"failure",'
        '"timestamp":"2026-08-05T13:00:00Z","actor_id":"admin-2",'
        '"client_id":"console","tenant_id":"acme"}],'
        '"count":2}';

    testWidgets('notEnabled variant when the events endpoint is gated', (
      tester,
    ) async {
      await _pumpWide(
        tester,
        AuditLogTab(api: _api({}), capabilities: _caps(const [])),
      );
      expect(
        find.text('This feature is not enabled on the connected replica.'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is EmptyState && w.variant == EmptyStateVariant.notEnabled,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'metrics + SectionHeader count + compact density + empty state',
      (tester) async {
        final api = _api({
          AuditReadClient.eventsPath: (_) => http.Response(eventsBody, 200),
        });
        await _pumpWide(
          tester,
          AuditLogTab(
            api: api,
            capabilities: _caps(const ['/api/v1/audit/events']),
            persona: OperatorPersona.auditor,
          ),
        );

        // Strip: error-rate card leads for auditor.
        expect(find.byType(KeyMetricCard), findsNWidgets(3));
        final errorRate = tester.getTopLeft(find.text('Error rate'));
        final entries = tester.getTopLeft(find.text('Entries'));
        expect(errorRate.dx, lessThan(entries.dx));
        expect(find.text('50'), findsOneWidget);
        expect(find.text('Success · 1'), findsOneWidget);
        expect(find.text('Failure · 1'), findsOneWidget);

        // SectionHeader with the live row count.
        expect(find.text('Recent events'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SectionHeader),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );

        // Audit passes compact density to the table.
        final table = tester.widget<AdminDataTable>(
          find.byType(AdminDataTable),
        );
        expect(table.density, TableDensity.compact);

        // Empty page → EmptyState.empty with the pinned title.
        final emptyApi = _api({
          AuditReadClient.eventsPath: (_) =>
              http.Response('{"events":[],"count":0}', 200),
        });
        await _pumpWide(
          tester,
          AuditLogTab(
            key: const ValueKey('empty'),
            api: emptyApi,
            capabilities: _caps(const ['/api/v1/audit/events']),
          ),
        );
        expect(
          find.text('No audit events returned by the server yet.'),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is EmptyState && w.variant == EmptyStateVariant.empty,
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('T-W1-07: client detail', () {
    Widget detail(
      Map<String, dynamic> payload, {
      OperatorPersona persona = OperatorPersona.general,
    }) => ClientDetailScreen(
      api: _api({}),
      client: _sso({
        '/api/v1/admin/clients/portal-client': (_) =>
            http.Response(jsonEncode({'client': payload}), 200),
      }),
      clientId: 'portal-client',
      persona: persona,
    );

    testWidgets('pending: StatusChip.pending + primary Approve + mini strip', (
      tester,
    ) async {
      await _pumpWide(
        tester,
        detail({
          'id': 'portal-client',
          'name': 'Portal',
          'status': 'pending',
          'grant_types': ['authorization_code', 'refresh_token'],
          'allowed_scopes': ['openid', 'profile'],
          'client_secret_expires_at': 0,
          'redirect_uris': ['https://app.example/cb'],
        }),
      );

      // Chip label renders context.tr('pending') — EN pin preserved.
      expect(find.text('pending'), findsOneWidget);
      final chip = tester.widget<StatusChip>(find.byType(StatusChip));
      expect(chip.label, 'pending');

      // Approve is a primary FilledButton; Reject stays outlined.
      expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Rotate Secret'),
        findsOneWidget,
      );

      // 3-card mini strip with real payload values.
      expect(find.byType(KeyMetricCard), findsNWidgets(3));
      // 'Grant types' appears both in the info card row and the strip card.
      expect(find.text('Grant types'), findsNWidgets(2));
      expect(find.text('Scopes'), findsOneWidget);
      // Info row ('Client secret') + strip caption both render it.
      expect(find.text('Never expires'), findsNWidgets(2));
      expect(find.text('2'), findsNWidgets(2));
    });

    testWidgets('active: no Approve; Rotate Secret stays primary', (
      tester,
    ) async {
      await _pumpWide(
        tester,
        detail({
          'id': 'portal-client',
          'name': 'Portal',
          'status': 'active',
          'active': true,
          'grant_types': ['authorization_code'],
          'allowed_scopes': ['openid'],
          'client_secret_expires_at': 0,
        }),
      );
      expect(find.text('active'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Rotate Secret'),
        findsOneWidget,
      );
    });
  });

  group('T-W1-08: user detail tab counts', () {
    testWidgets('count suffix only when count > 0; bare label otherwise', (
      tester,
    ) async {
      final client = _sso({
        '/api/v1/admin/users/user-1': (_) => http.Response(
          jsonEncode({
            'user': {'id': 'user-1', 'provider': 'local'},
          }),
          200,
        ),
      });
      final api = _api({
        '/api/v1/admin/users/user-1/sessions': (_) => http.Response(
          jsonEncode({
            'sessions': [
              {'id': 's-1'},
              {'id': 's-2'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/users/user-1/consents': (_) =>
            http.Response(jsonEncode({'consents': <Object>[]}), 200),
        '/api/v1/admin/users/user-1/mfa': (_) =>
            http.Response(jsonEncode({'factors': <Object>[]}), 200),
        '/api/v1/admin/users/user-1/lifecycle': (_) =>
            http.Response(jsonEncode(<String, dynamic>{}), 200),
      });
      await _pumpWide(
        tester,
        UserDetailScreen(
          api: api,
          client: client,
          userId: 'user-1',
          capabilities: _caps(const []),
        ),
      );

      // Sessions count > 0 → suffixed label.
      expect(find.text('Sessions  (2)'), findsOneWidget);
      expect(find.text('Sessions'), findsNothing);
      // Zero/absent counts → bare labels.
      expect(find.text('Consents'), findsOneWidget);
      expect(find.text('MFA'), findsOneWidget);
      expect(find.text('Lifecycle'), findsOneWidget);
      expect(find.text('Device security'), findsOneWidget);
      expect(find.textContaining('(0)'), findsNothing);
    });

    testWidgets('empty sessions fixture keeps the bare pinned label', (
      tester,
    ) async {
      final client = _sso({
        '/api/v1/admin/users/user-1': (_) => http.Response(
          jsonEncode({
            'user': {'id': 'user-1', 'provider': 'local'},
          }),
          200,
        ),
      });
      final api = _api({
        '/api/v1/admin/users/user-1/sessions': (_) =>
            http.Response(jsonEncode({'sessions': <Object>[]}), 200),
        '/api/v1/admin/users/user-1/consents': (_) =>
            http.Response(jsonEncode({'consents': <Object>[]}), 200),
        '/api/v1/admin/users/user-1/mfa': (_) =>
            http.Response(jsonEncode({'factors': <Object>[]}), 200),
        '/api/v1/admin/users/user-1/lifecycle': (_) =>
            http.Response(jsonEncode(<String, dynamic>{}), 200),
      });
      await _pumpWide(
        tester,
        UserDetailScreen(
          api: api,
          client: client,
          userId: 'user-1',
          capabilities: _caps(const []),
        ),
      );
      // Exact-match pins at user_detail_optional_resources_test.dart:71-72.
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Device security'), findsOneWidget);
    });
  });

  group('T-W1-09: tenant detail', () {
    testWidgets('metric strip + StatusChip.active in residency summary', (
      tester,
    ) async {
      final client = _sso({
        '/api/v1/admin/tenants/tenant-a': (_) => http.Response(
          jsonEncode({
            'tenant': {
              'id': 'tenant-a',
              'name': 'Acme',
              'slug': 'acme',
              'status': 'active',
              'home_region': 'eu-west-1',
            },
          }),
          200,
        ),
      });
      final api = _api({
        '/api/v1/admin/tenants/tenant-a/members': (_) => http.Response(
          jsonEncode({
            'members': [
              {'user_id': 'u-1'},
              {'user_id': 'u-2'},
              {'user_id': 'u-3'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/tenants/tenant-a/invitations': (_) => http.Response(
          jsonEncode({
            'invitations': [
              {'email': 'a@b.c'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/tenants/tenant-a/usage': (_) =>
            http.Response('{"usage":{}}', 200),
      });
      await _pumpWide(
        tester,
        TenantDetailScreen(
          api: api,
          client: client,
          tenantId: 'tenant-a',
          capabilities: _caps(const []),
          persona: OperatorPersona.general,
        ),
      );

      // Residency summary chip label via context.tr('active').
      final chip = tester.widget<StatusChip>(find.byType(StatusChip));
      expect(chip.label, 'active');

      // 3-card mini strip with real payload values.
      expect(find.byType(KeyMetricCard), findsNWidgets(3));
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Invitations'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('eu-west-1'), findsOneWidget);
    });
  });
}
