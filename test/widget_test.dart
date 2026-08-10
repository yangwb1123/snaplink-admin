@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/app_router.dart';
import 'package:sso_admin/main.dart';
import 'package:sso_admin/services/product_entry_route.dart';

void main() {
  testWidgets('App boots to the unified first-party login screen by default', (
    WidgetTester tester,
  ) async {
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/auth/login') {
          return http.Response(
            '{"providers":[{"id":"password","type":"builtin"}]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);

    // Preload the code-split login chunk explicitly: in browser tests the
    // chunk fetch is real asynchronous I/O, which fixed pump counts cannot
    // reliably wait for. After this, resolveProductScreen renders the login
    // screen synchronously (no DeferredEntryScreen loading frame).
    await tester.runAsync(() => preloadProductEntry(ProductEntry.login));

    await tester.pumpWidget(SSOConsoleApp(oidcLoginApi: api));
    // The screen briefly shows a spinner while it checks whether this load is
    // a federated-login return leg (an async gap even on a plain first load).
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    // Federated buttons are rendered only from Snaplink's provider discovery
    // response; the boot fallback must not advertise hard-coded providers.
    expect(find.textContaining('Google'), findsNothing);
    expect(find.textContaining('GitHub'), findsNothing);
  });
}
