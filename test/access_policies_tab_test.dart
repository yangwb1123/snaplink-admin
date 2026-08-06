import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/access_policies_tab.dart';

void main() {
  test('policy helpers project current CAP conditions and actions', () {
    final policy = <String, dynamic>{
      'actions': {
        'require_step_up': 'mfa',
        'restrict_scopes': ['openid'],
      },
      'conditions': {
        'session_max_concurrent': 2,
        'authentication_age_seconds': 3600,
      },
    };
    expect(accessPolicyVerdict(policy), 'Require step-up: mfa');
    expect(accessPolicyScopeCeiling(policy), ['openid']);
    expect(
      accessPolicyConditionLabels(policy),
      contains('Session Max Concurrent: 2'),
    );
  });

  testWidgets('admin can confirm and run active-session convergence', (
    tester,
  ) async {
    var postCount = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'policies': [
              {
                'name': 'session-cap',
                'enabled': true,
                'priority': 10,
                'conditions': {'session_max_concurrent': 2},
                'actions': {'deny': true},
              },
            ],
          }),
          200,
        );
      }
      expect(request.url.path, accessPolicyConvergePath);
      postCount++;
      return http.Response(
        jsonEncode({
          'scanned': 3,
          'revoked': 1,
          'step_up_marked': 0,
          'scopes_restricted': 0,
          'failed': 0,
        }),
        200,
      );
    });
    final api = SnaplinkAdminApi(
      baseUrl: 'https://snaplink.test',
      accessToken: 'admin-token',
      httpClient: client,
    );
    const capabilities = SnaplinkAdminCapabilities([
      SnaplinkAdminEndpoint(
        method: 'GET',
        path: accessPoliciesPath,
        feature: 'admin_api',
      ),
      SnaplinkAdminEndpoint(
        method: 'POST',
        path: accessPolicyConvergePath,
        feature: 'admin_api',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessPoliciesTab(api: api, capabilities: capabilities),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('session-cap'), findsOneWidget);
    await tester.tap(find.text('Apply to active sessions'));
    await tester.pumpAndSettle();
    expect(find.text('Apply current policies?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(postCount, 1);
    expect(find.textContaining('3 scanned, 1 revoked'), findsOneWidget);
  });
}
