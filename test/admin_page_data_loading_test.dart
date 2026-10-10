import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/screens/admin/admin_module_groups.dart';
import 'package:sso_admin/screens/admin/admin_navigation.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
import 'package:sso_admin/screens/admin/dashboard_navigation_entries.dart';
import 'package:sso_admin/screens/admin/commerce/commerce_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';

import 'fixtures/admin_page_fixture.dart';

void main() {
  setUp(BrowserNavigation.resetForTest);
  final modules = [for (final group in adminModuleGroups) ...group.modules];
  for (final module in modules) {
    testWidgets('page data contract: /admin/$module', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = AdminPageFixture();
      BrowserNavigation.pushState(AdminRoute.url(module));
      final navigation = buildDashboardNavigationEntries(
        client: fixture.client,
        api: fixture.api,
        endpoints: SnaplinkAdminOperationCatalog.endpoints,
        capabilitiesError: null,
        onRefresh: () {},
        strings: AppStrings.forLocale(const Locale('en')),
        commerceAvailable: false,
        commerceProbeError: null,
      );
      // Commerce needs its independent service. Exercise it with an explicit
      // healthy service probe, not a core-inventory capability guess.
      final entries = module == AdminModuleId.commerce
          ? buildDashboardNavigationEntries(
              client: fixture.client,
              api: fixture.api,
              endpoints: SnaplinkAdminOperationCatalog.endpoints,
              capabilitiesError: null,
              onRefresh: () {},
              strings: AppStrings.forLocale(const Locale('en')),
              commerceAvailable: true,
              commerceProbeError: null,
            ).entries
          : navigation.entries;
      final entry = entries.singleWhere((e) => e.module == module);
      final page = module == AdminModuleId.commerce
          ? CommerceTab(api: fixture.api, probeClientBuilder: () => fixture.api)
          : entry.page;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '/admin/$module must render server data',
      );
      expect(find.textContaining('Missing page fixture'), findsNothing);
      expect(find.textContaining('Could not load'), findsNothing);
      expect(find.textContaining('could not be loaded'), findsNothing);
      expect(find.textContaining('Admin request failed'), findsNothing);
      expect(find.textContaining('SSO request failed'), findsNothing);
      expect(find.textContaining('invalid JSON response'), findsNothing);
      expect(
        fixture.unhandled,
        isEmpty,
        reason: 'Every request must have a published response fixture',
      );
      expect(fixture.requests.every((r) => r.method == 'GET'), isTrue);
      // Pin actual data on the primary lists; metadata-first proto responses
      // must not quietly become empty tables or lose pagination information.
      if (module == AdminModuleId.clients) {
        expect(find.text('Contract client'), findsWidgets);
      } else if (module == AdminModuleId.users) {
        expect(find.text('external-1'), findsWidgets);
      } else if (module == AdminModuleId.tenants) {
        expect(find.text('Contract tenant'), findsWidgets);
      } else if (module == AdminModuleId.webhooks) {
        expect(find.textContaining('webhook-1'), findsWidgets);
        expect(find.text('dead-1'), findsWidgets);
        expect(find.text('fixture delivery failure'), findsWidgets);
      } else if (module == AdminModuleId.tokenPolicies) {
        expect(fixture.paths, contains('/api/v1/admin/token-policies'));
      } else if (module == AdminModuleId.commerce) {
        expect(find.textContaining('Contract plan'), findsWidgets);
      } else if (module == AdminModuleId.recoveryReleases) {
        expect(find.text('snapshot-1'), findsWidgets);
        expect(find.text('release-1'), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox());
      fixture.transport.close();
    });
  }
}
