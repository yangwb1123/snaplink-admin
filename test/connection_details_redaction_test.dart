import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/connections/details_card.dart';
import 'package:sso_admin/services/sensitive_data.dart';

void main() {
  testWidgets('connection config is deeply redacted before rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionDetailsCard(
            id: 'connection-1',
            connection: const {
              'id': 'connection-1',
              'display_name': 'Example OIDC',
              'type': 'oidc',
              'config': {
                'issuer': 'https://idp.example.test',
                'oidc_client_secret': 'must-not-render',
                'nested': {'auth_token': 'also-must-not-render'},
              },
            },
            health: null,
            domainClaims: const [],
            loading: false,
            mutating: false,
            canProbe: false,
            canListDomains: false,
            canVerifyDomain: false,
            canDelete: false,
            onRefresh: () {},
            onProbe: () {},
            onDelete: () {},
            onVerifyDomain: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('must-not-render'), findsNothing);
    expect(find.textContaining('also-must-not-render'), findsNothing);
    expect(find.textContaining(SensitiveData.redacted), findsWidgets);
    expect(find.textContaining('https://idp.example.test'), findsOneWidget);
  });
}
