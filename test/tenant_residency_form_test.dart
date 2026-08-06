import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/tenant_form_dialog.dart';
import 'package:sso_admin/screens/admin/tenant_residency_fields.dart';

void main() {
  test('normalizes tenant serving regions while preserving order', () {
    expect(parseTenantRegions(' eu-west-1,us-east-1\neu-west-1,, '), [
      'eu-west-1',
      'us-east-1',
    ]);
  });

  testWidgets('creates a tenant with an explicit residency policy', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    final client = await _loggedInClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/admin/tenants');
      submitted = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'tenant': submitted}), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TenantFormDialog(client: client)),
      ),
    );
    await tester.enterText(_field('ID'), 'acme');
    await tester.enterText(_field('Slug'), ' acme ');
    await tester.enterText(_field('Name'), ' Acme ');
    await tester.enterText(_field('Home region'), ' eu-west-1 ');
    await tester.enterText(
      _field('Allowed serving regions'),
      'eu-west-1, us-east-1\neu-west-1',
    );
    final enforcement = find.byKey(const ValueKey('tenant-enforce-writes'));
    await tester.ensureVisible(enforcement);
    tester.widget<SwitchListTile>(enforcement).onChanged!(true);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(enforcement).value, isTrue);
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(submitted, containsPair('home_region', 'eu-west-1'));
    expect(
      submitted,
      containsPair('allowed_regions', ['eu-west-1', 'us-east-1']),
    );
    expect(submitted, containsPair('enforce_writes', true));
    expect(submitted, containsPair('slug', 'acme'));
    expect(submitted, containsPair('name', 'Acme'));
  });

  testWidgets('requires a home region before enforcing writes', (tester) async {
    var requestSent = false;
    final client = await _loggedInClient((_) async {
      requestSent = true;
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TenantFormDialog(client: client)),
      ),
    );
    await tester.enterText(_field('ID'), 'acme');
    final enforcement = find.byKey(const ValueKey('tenant-enforce-writes'));
    await tester.ensureVisible(enforcement);
    tester.widget<SwitchListTile>(enforcement).onChanged!(true);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(enforcement).value, isTrue);
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('tenant-home-region')),
    );

    expect(
      find.text('Home region is required when write enforcement is enabled.'),
      findsOneWidget,
    );
    expect(requestSent, isFalse);
  });

  testWidgets('editing can clear a tenant residency policy', (tester) async {
    Map<String, dynamic>? submitted;
    final client = await _loggedInClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v1/admin/tenants/acme');
      submitted = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'tenant': submitted}), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TenantFormDialog(
            client: client,
            existing: const {
              'id': 'acme',
              'slug': 'acme',
              'name': 'Acme',
              'settings': {'locale': 'en'},
              'home_region': 'eu-west-1',
              'allowed_regions': ['eu-west-1', 'eu-central-1'],
              'enforce_writes': true,
            },
          ),
        ),
      ),
    );
    await tester.enterText(_field('Home region'), '');
    await tester.enterText(_field('Allowed serving regions'), '');
    final enforcement = find.byKey(const ValueKey('tenant-enforce-writes'));
    await tester.ensureVisible(enforcement);
    tester.widget<SwitchListTile>(enforcement).onChanged!(false);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(enforcement).value, isFalse);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(submitted, containsPair('home_region', ''));
    expect(submitted, containsPair('allowed_regions', <dynamic>[]));
    expect(submitted, containsPair('enforce_writes', false));
    expect(submitted, containsPair('settings', {'locale': 'en'}));
    expect(submitted!.containsKey('status'), isFalse);
  });
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<SSOAdminClient> _loggedInClient(
  Future<http.Response> Function(http.Request request) handler,
) async {
  var loggedIn = false;
  final client = SSOAdminClient(
    'https://sso.example.test',
    httpClient: MockClient((request) async {
      if (!loggedIn) {
        loggedIn = true;
        return http.Response('{"access_token":"admin-token"}', 200);
      }
      return handler(request);
    }),
  );
  await client.login('admin', 'password');
  return client;
}
