import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/admin_navigation.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
import 'package:sso_admin/screens/admin/dashboard_capability_gate.dart';
import 'package:sso_admin/screens/admin/dashboard_page_resolution.dart';
import 'package:sso_admin/services/operator_persona.dart';

SnaplinkAdminCapabilitySnapshot _snapshot({
  bool loading = false,
  bool available = true,
  List<SnaplinkAdminEndpoint> endpoints = const [],
}) => SnaplinkAdminCapabilitySnapshot(
  effective: SnaplinkAdminCapabilities(SnaplinkAdminOperationCatalog.endpoints),
  runtime: SnaplinkAdminCapabilities(endpoints),
  runtimeInventoryLoading: loading,
  runtimeInventoryAvailable: available,
);

const _families = <String, String>{
  AdminModuleId.connections: '/api/v1/admin/connections',
  AdminModuleId.networkPolicies: '/api/v1/netpolicy/policies',
  AdminModuleId.accessPolicies: '/api/v1/admin/access-policies',
  AdminModuleId.webhooks: '/api/v1/admin/webhooks/subscriptions',
};

void main() {
  for (final family in _families.entries) {
    testWidgets('${family.key}: absent runtime family never mounts the page', (
      tester,
    ) async {
      var mounts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: dashboardCapabilityGate(
            module: family.key,
            snapshot: _snapshot(),
            child: _FetchProbe(onMount: () => mounts++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mounts, 0);
      expect(
        find.text('This feature is not enabled on the connected replica.'),
        findsOneWidget,
      );
    });

    testWidgets('${family.key}: unknown inventory allows retry, not fetch', (
      tester,
    ) async {
      var mounts = 0;
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: dashboardCapabilityGate(
            module: family.key,
            snapshot: _snapshot(available: false),
            onRetry: () => retries++,
            child: _FetchProbe(onMount: () => mounts++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mounts, 0);
      expect(find.text('Capability inventory is unavailable'), findsOneWidget);
      expect(
        find.text('This feature is not enabled on the connected replica.'),
        findsNothing,
      );
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('${family.key}: advertised family mounts its real page', (
      tester,
    ) async {
      var mounts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: dashboardCapabilityGate(
            module: family.key,
            snapshot: _snapshot(
              endpoints: [
                SnaplinkAdminEndpoint(
                  method: 'GET',
                  path: family.value,
                  feature: 'admin_api',
                ),
              ],
            ),
            child: _FetchProbe(onMount: () => mounts++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mounts, 1);
      expect(find.text('Actual page'), findsOneWidget);
    });
  }

  testWidgets('loading inventory does not mount or claim a disabled feature', (
    tester,
  ) async {
    var mounts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: dashboardCapabilityGate(
          module: AdminModuleId.connections,
          snapshot: _snapshot(loading: true, available: false),
          child: _FetchProbe(onMount: () => mounts++),
        ),
      ),
    );
    await tester.pump();
    expect(mounts, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Capability inventory is unavailable'), findsNothing);
  });

  testWidgets('independent services and catalog-only routes are not gated', (
    tester,
  ) async {
    for (final module in [
      AdminModuleId.auditLog,
      AdminModuleId.commerce,
      AdminModuleId.localUsers,
      AdminModuleId.domains,
      AdminModuleId.cryptoKeys,
    ]) {
      var mounts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: dashboardCapabilityGate(
            module: module,
            snapshot: _snapshot(available: false),
            child: _FetchProbe(key: ValueKey(module), onMount: () => mounts++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mounts, 1, reason: '$module has its own availability contract');
    }
  });

  testWidgets(
    'blocked deep link preserves its module heading without fetching',
    (tester) async {
      var mounts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: dashboardCapabilityGate(
            module: AdminModuleId.webhooks,
            title: 'Webhooks',
            snapshot: _snapshot(available: false),
            child: _FetchProbe(onMount: () => mounts++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Webhooks'), findsOneWidget);
      expect(find.text('Capability inventory is unavailable'), findsOneWidget);
      expect(mounts, 0);
    },
  );

  for (final module in [AdminModuleId.connections, AdminModuleId.webhooks]) {
    testWidgets('$module detail deep link cannot bypass the runtime boundary', (
      tester,
    ) async {
      var requests = 0;
      final transport = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'fixture',
        httpClient: transport,
      );
      final client = SSOAdminClient(
        'https://sso.example.test',
        httpClient: transport,
      );
      final page = resolveDashboardPage(
        route: AdminRoute(module: module, resourceId: 'resource-1'),
        selectedModule: module,
        entries: const [
          AdminNavigationEntry(
            module: AdminModuleId.overview,
            destination: NavigationRailDestination(
              icon: Icon(Icons.dashboard),
              label: Text('Overview'),
            ),
            page: Text('Overview'),
          ),
        ],
        api: api,
        client: client,
        capabilities: _snapshot().effective,
        capabilitySnapshot: _snapshot(),
        persona: OperatorPersona.general,
      );
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(
        find.text('This feature is not enabled on the connected replica.'),
        findsOneWidget,
      );
    });
  }
}

class _FetchProbe extends StatefulWidget {
  final VoidCallback onMount;
  const _FetchProbe({super.key, required this.onMount});

  @override
  State<_FetchProbe> createState() => _FetchProbeState();
}

class _FetchProbeState extends State<_FetchProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const Text('Actual page');
}
