import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/oidc_login/consent_view.dart';
import 'package:sso_admin/screens/oidc_login/hosted_login_models.dart';

void main() {
  testWidgets('renders server descriptions and the exact RAR request', (
    tester,
  ) async {
    var allowed = false;
    final summary = ConsentRequestSummary.fromResponse({
      'scopes': [
        {'scope': 'billing:read', 'description': 'View your billing history'},
      ],
      'authorization_details': [
        {
          'type': 'payment_initiation',
          'actions': ['initiate'],
          'identifier': 'invoice-42',
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConsentView(
            clientName: 'Acme Console',
            clientId: 'acme-client',
            summary: summary,
            loading: false,
            onAllow: () => allowed = true,
            onDeny: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Acme Console'), findsOneWidget);
    expect(find.text('View your billing history'), findsOneWidget);
    expect(find.text('Scope: billing:read'), findsOneWidget);
    expect(find.textContaining('payment_initiation'), findsWidgets);
    expect(find.textContaining('invoice-42'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    expect(allowed, isTrue);
  });

  testWidgets('disables authorization when the server summary is empty', (
    tester,
  ) async {
    final summary = ConsentRequestSummary.fromResponse({'scopes': []});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConsentView(
            clientName: 'Acme Console',
            clientId: 'acme-client',
            summary: summary,
            loading: false,
            onAllow: () {},
            onDeny: () {},
          ),
        ),
      ),
    );

    final allow = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Allow'),
    );
    expect(allow.onPressed, isNull);
    expect(
      find.textContaining('Authorization has been disabled'),
      findsOneWidget,
    );
  });
}
