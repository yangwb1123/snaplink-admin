import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/tenant_branding_tab.dart';

void main() {
  testWidgets('branding reset preserves non-brand tenant settings via PUT', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1100);
    addTearDown(tester.view.reset);
    Map<String, dynamic>? savedBody;
    final methods = <String>[];
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example',
      accessToken: 'token',
      httpClient: MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'PUT') {
          savedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'branding': {
              'brand_name': 'Example',
              'primary_color': '#123456',
              'locale': 'en-US',
              'feature_flag': 'enabled',
            },
          }),
          200,
        );
      }),
    )..maxRetries = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TenantBrandingTab(api: api, tenantId: 'tenant-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'JSON object',
      ),
      '{"locale":"unreviewed-edit","new_flag":"must-not-save"}',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Restore defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore defaults'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'tenant-1',
    );
    await tester.pump();
    await tester.tap(find.text('Remove branding keys'));
    await tester.pumpAndSettle();

    expect(methods, ['GET', 'PUT', 'GET']);
    expect(savedBody?['branding'], {
      'locale': 'en-US',
      'feature_flag': 'enabled',
    });
  });

  testWidgets(
    'branding save reconciles a transport-unknown result with one safe GET',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1100);
      addTearDown(tester.view.reset);
      final methods = <String>[];
      var getCount = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example',
        accessToken: 'token',
        httpClient: MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'PUT') {
            throw TimeoutException('response lost');
          }
          getCount++;
          return http.Response(
            jsonEncode({
              'branding': {
                'brand_name': getCount == 1 ? 'Before' : 'Server state',
                'locale': 'en-US',
              },
            }),
            200,
          );
        }),
      )..maxRetries = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TenantBrandingTab(api: api, tenantId: 'tenant-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Brand name',
        ),
        'Draft',
      );
      await tester.ensureVisible(find.text('Save branding'));
      await tester.tap(find.text('Save branding'));
      await tester.pumpAndSettle();

      expect(methods, ['GET', 'PUT', 'GET']);
      expect(find.textContaining('Branding save result is unknown'), findsOne);
      expect(find.textContaining('A safe GET refreshed'), findsOne);
      expect(find.text('Server state'), findsNWidgets(2));
    },
  );

  testWidgets(
    'branding reset reports unknown HTTP result when safe refresh fails',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1100);
      addTearDown(tester.view.reset);
      final methods = <String>[];
      var getCount = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example',
        accessToken: 'token',
        httpClient: MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'PUT') {
            return http.Response(
              jsonEncode({'message': 'gateway unavailable'}),
              503,
            );
          }
          getCount++;
          if (getCount == 2) {
            throw http.ClientException('refresh unavailable');
          }
          return http.Response(
            jsonEncode({
              'branding': {
                'brand_name': getCount == 1 ? 'Example' : 'Reconciled',
                'locale': 'en-US',
              },
            }),
            200,
          );
        }),
      )..maxRetries = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TenantBrandingTab(api: api, tenantId: 'tenant-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Restore defaults'));
      await tester.tap(find.text('Restore defaults'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'tenant-1',
      );
      await tester.pump();
      await tester.tap(find.text('Remove branding keys'));
      await tester.pumpAndSettle();

      expect(methods, ['GET', 'PUT', 'GET']);
      expect(
        find.textContaining('Branding reset result is unknown (HTTP 503)'),
        findsOne,
      );
      expect(find.textContaining('safe GET refresh failed'), findsOne);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save branding'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Restore defaults'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is TextField &&
                    widget.decoration?.labelText == 'Brand name',
              ),
            )
            .enabled,
        isFalse,
      );

      await tester.tap(find.text('Retry reconciliation'));
      await tester.pumpAndSettle();

      expect(methods, ['GET', 'PUT', 'GET', 'GET']);
      expect(methods.where((method) => method == 'PUT'), hasLength(1));
      expect(find.text('Retry reconciliation'), findsNothing);
      expect(find.textContaining('current state is now reconciled'), findsOne);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save branding'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Restore defaults'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is TextField &&
                    widget.decoration?.labelText == 'Brand name',
              ),
            )
            .enabled,
        isTrue,
      );
    },
  );
}
