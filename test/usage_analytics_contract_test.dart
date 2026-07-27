import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/usage_analytics_contract.dart';

void main() {
  test('normalizes the actual PascalCase TenantUsage wire shape', () {
    final result = normalizeTenantUsageRecord({
      'TenantID': 'tenant-a',
      'Period': 'day',
      'PeriodStart': '2026-07-27T00:00:00Z',
      'Logins': 12,
      'TokensIssued': 34,
      'ActiveUsers': 5,
      'ActiveClients': 3,
      'MFAChallenges': 2,
    });

    expect(result['tenant_id'], 'tenant-a');
    expect(result['period_start'], '2026-07-27T00:00:00Z');
    expect(result['logins'], 12);
    expect(result['tokens_issued'], 34);
    expect(result['active_users'], 5);
    expect(result['active_clients'], 3);
    expect(result['mfa_challenges'], 2);
  });

  test(
    'preserves canonical snake_case fields when both shapes are present',
    () {
      final result = normalizeTopTenantsPayload({
        'tenants': [
          {'TenantID': 'legacy', 'tenant_id': 'canonical', 'Logins': 4},
        ],
      });

      final tenants = result['tenants'] as List;
      expect((tenants.single as Map)['tenant_id'], 'canonical');
      expect((tenants.single as Map)['logins'], 4);
    },
  );
}
