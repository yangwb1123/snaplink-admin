import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';
import 'package:sso_admin/screens/admin/admin_ops_helpers.dart';
import 'package:sso_admin/services/sensitive_data.dart';

void main() {
  test('deep redaction covers credential key variants but keeps metadata', () {
    final redacted =
        SensitiveData.redact({
              'config': {
                'oidc_client_secret': 'oidc-value',
                'auth_token': 'auth-value',
                'deviceToken': 'device-value',
                'impersonation_token': 'impersonation-value',
                'signingKey': 'signing-value',
                'encryption_key': 'encryption-value',
                'sharedKey': 'shared-value',
                'clientAssertion': 'assertion-value',
                'nested': [
                  {'private_key': 'private-value'},
                ],
              },
              'token_type': 'Bearer',
              'token_strategy': 'jwt',
              'token_count': 4,
              'tokens': ['inventory-token-value'],
              'refresh_tokens': ['refresh-value'],
              'password_reset_tokens': ['reset-value'],
              'resources_json': 'decoded-snapshot-credentials',
            })
            as Map<String, dynamic>;
    final encoded = jsonEncode(redacted);

    for (final raw in const [
      'oidc-value',
      'auth-value',
      'device-value',
      'impersonation-value',
      'signing-value',
      'encryption-value',
      'shared-value',
      'assertion-value',
      'private-value',
      'inventory-token-value',
      'refresh-value',
      'reset-value',
      'decoded-snapshot-credentials',
    ]) {
      expect(encoded, isNot(contains(raw)));
    }
    expect(encoded, contains(SensitiveData.redacted));
    expect(redacted['token_type'], 'Bearer');
    expect(redacted['token_strategy'], 'jwt');
    expect(redacted['token_count'], 4);
  });

  test('generic admin console allows server-redacted provider DTOs', () {
    for (final path in const [
      '/api/v1/admin/providers',
      '/api/v1/admin/providers/oidc',
    ]) {
      expect(
        AdminOpsHelpers.exposesUnredactedProviderConfig(
          SnaplinkAdminEndpoint(
            method: 'GET',
            path: path,
            feature: 'supplemental',
          ),
        ),
        isFalse,
      );
    }
    expect(
      AdminOpsHelpers.exposesUnredactedProviderConfig(
        const SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/connections',
          feature: 'connections',
        ),
      ),
      isFalse,
    );
  });

  test('write confirmation is bound to the exact resolved resource', () {
    expect(
      AdminOpsHelpers.writeConfirmation(
        'delete',
        '/api/v1/admin/users/user-42',
      ),
      'CONFIRM DELETE /api/v1/admin/users/user-42',
    );
  });

  test('generic operations allow server-redacted snapshot detail reads', () {
    expect(
      AdminOpsHelpers.exposesDecodedSnapshotResources(
        const SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/snapshots/{id}',
          feature: 'documented',
        ),
      ),
      isFalse,
    );
    expect(
      AdminOpsHelpers.exposesDecodedSnapshotResources(
        const SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/snapshots',
          feature: 'documented',
        ),
      ),
      isFalse,
    );
  });

  test('generic operations cannot bypass dedicated high-risk workflows', () {
    for (final route in const [
      ('DELETE', '/api/v1/admin/branding'),
      ('POST', '/api/v1/scim/v2/Bulk'),
      ('POST', '/api/v1/admin/snapshots/{id}:restore'),
      ('POST', '/api/v1/admin/releases/{id}:rollback'),
      ('POST', '/api/v1/admin/devices/bulk-revoke'),
      ('POST', '/api/v1/admin/tokens/bulk-revoke'),
      ('POST', '/api/v1/admin/compliance/retention-sweep'),
      ('POST', '/api/v1/admin/tenants/{id}/export'),
      ('POST', '/api/v1/compliance/users/{id}/erase'),
    ]) {
      expect(
        AdminOpsHelpers.requiresDedicatedWorkflow(
          SnaplinkAdminEndpoint(
            method: route.$1,
            path: route.$2,
            feature: 'documented',
          ),
        ),
        isTrue,
        reason: '${route.$1} ${route.$2}',
      );
    }
    expect(
      AdminOpsHelpers.requiresDedicatedWorkflow(
        const SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/users',
          feature: 'documented',
        ),
      ),
      isFalse,
    );
  });
}
