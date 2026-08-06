import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/tenant_residency_summary.dart';

void main() {
  testWidgets('shows the effective tenant residency policy', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TenantResidencySummary(
            fallbackId: 'acme',
            tenant: {
              'id': 'acme',
              'name': 'Acme',
              'status': 'active',
              'home_region': 'eu-west-1',
              'allowed_regions': ['eu-west-1', 'eu-central-1'],
              'enforce_writes': true,
            },
          ),
        ),
      ),
    );

    expect(find.text('Home region: eu-west-1'), findsOneWidget);
    expect(
      find.text('Allowed serving regions: eu-west-1, eu-central-1'),
      findsOneWidget,
    );
    expect(find.text('Write enforcement enabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warns when legacy write enforcement has no home region', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TenantResidencySummary(
            fallbackId: 'legacy',
            tenant: {'id': 'legacy', 'enforce_writes': true},
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Write enforcement is inactive because no home region is configured.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('keeps unconstrained tenants free of residency badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TenantResidencySummary(
            fallbackId: 'global',
            tenant: {'id': 'global', 'status': 'active'},
          ),
        ),
      ),
    );

    expect(find.textContaining('Home region:'), findsNothing);
    expect(find.textContaining('Allowed serving regions:'), findsNothing);
    expect(find.textContaining('Write enforcement'), findsNothing);
  });
}
