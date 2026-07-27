import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/device_bulk_revoke_dialog.dart';
import 'package:sso_admin/screens/admin/device_security_models.dart';

void main() {
  testWidgets(
    'bulk revoke requires a filter, estimate, and typed confirmation',
    (tester) async {
      final requests = <http.Request>[];
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'GET');
          expect(request.url.path, DeviceSecurityPaths.devices);
          return http.Response(
            '{"devices":['
            '{"id":"risky","suspicious":true,"trust_score":0.2},'
            '{"id":"safe","suspicious":false,"trust_score":0.9}'
            '],"total":2}',
            200,
          );
        }),
      );
      DeviceBulkRevokeFilter? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await DeviceBulkRevokeDialog.show(context, api: api);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      Finder filledButtonWithText(String text) => find.ancestor(
        of: find.text(text),
        matching: find.bySubtype<FilledButton>(),
      );
      FilledButton continueButton() =>
          tester.widget(filledButtonWithText('Continue'));
      expect(continueButton().onPressed, isNull);

      await tester.tap(find.text('Estimate matches'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(find.textContaining('unfiltered revocation'), findsOneWidget);

      await tester.tap(find.text('Only devices flagged suspicious'));
      await tester.pump();
      await tester.tap(find.text('Estimate matches'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(find.text('Estimated matches: 1'), findsOneWidget);
      expect(continueButton().onPressed, isNotNull);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('REVOKE 1 DEVICES'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(filledButtonWithText('Revoke devices'))
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField).last, 'REVOKE 1 DEVICES');
      await tester.pump();
      await tester.tap(find.text('Revoke devices'));
      await tester.pumpAndSettle();

      expect(result?.toRequestBody(), {'suspicious': true});
      expect(requests, hasLength(1), reason: 'The dialog never mutates data.');
    },
  );
}
