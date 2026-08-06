import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/device_security_dashboard_widgets.dart';
import 'package:sso_admin/screens/admin/governance_widgets.dart';
import 'package:sso_admin/screens/admin/tenant_organization_cards.dart';
import 'package:sso_admin/screens/oidc_login/webauthn_assertion_stub.dart';
import 'package:sso_admin/screens/oidc_login/webauthn_registration_stub.dart';

void main() {
  group('DeviceStatsCards', () {
    testWidgets('renders fleet statistics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceStatsCards(
              stats: {
                'total': 12,
                'suspicious': 2,
                'trust_levels': {'very_low': 1},
                'platforms': {'linux': 5},
              },
              fleetTotal: 12,
            ),
          ),
        ),
      );
      expect(find.text('Fleet devices'), findsOneWidget);
      expect(find.text('12'), findsWidgets);
      expect(find.text('Suspicious'), findsOneWidget);
      expect(find.text('Very low trust'), findsOneWidget);
    });
  });

  group('DeviceFleetFilters', () {
    testWidgets('renders the filter form', (tester) async {
      final user = TextEditingController();
      final platform = TextEditingController();
      final ip = TextEditingController();
      addTearDown(user.dispose);
      addTearDown(platform.dispose);
      addTearDown(ip.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceFleetFilters(
              userController: user,
              platformController: platform,
              ipController: ip,
              deviceType: '',
              trustLevel: '',
              suspiciousOnly: false,
              loading: false,
              onDeviceTypeChanged: (_) {},
              onTrustLevelChanged: (_) {},
              onSuspiciousChanged: (_) {},
              onApply: () {},
              onClear: () {},
            ),
          ),
        ),
      );
      expect(find.byType(DeviceFleetFilters), findsOneWidget);
    });
  });

  group('OrganizationInvitationsCard', () {
    testWidgets('sends an invitation and revokes a pending one', (
      tester,
    ) async {
      final email = TextEditingController();
      addTearDown(email.dispose);
      String? revoked;
      var sent = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizationInvitationsCard(
              invitations: [
                {'email': 'invitee@example.com', 'status': 'pending'},
              ],
              emailController: email,
              role: 'member',
              mutating: false,
              onRoleChanged: (_) {},
              onSend: () => sent++,
              onRevoke: (value) => revoked = value,
            ),
          ),
        ),
      );

      expect(find.text('invitee@example.com'), findsOneWidget);
      await tester.tap(find.text('Send invitation'));
      expect(sent, 1);
      await tester.tap(find.text('Revoke'));
      expect(revoked, 'invitee@example.com');
    });
  });

  group('GovernanceWidgets', () {
    testWidgets('renders a section with cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GovernanceSection(
              title: 'Health',
              children: [
                GovernanceCard(
                  title: 'Storage health',
                  children: [const Text('ok')],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('Storage health'), findsOneWidget);
      expect(find.text('ok'), findsOneWidget);
    });
  });

  group('WebAuthn stubs', () {
    test('assertion stub fails closed on the VM', () async {
      expect(
        () => WebAuthnAssertion.request({'challenge': 'x'}),
        throwsStateError,
      );
    });

    test('registration stub fails closed on the VM', () async {
      expect(
        () => WebAuthnRegistration.create({'challenge': 'x'}),
        throwsStateError,
      );
    });
  });
}
