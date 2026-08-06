import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/break_glass_widgets.dart';
import 'package:sso_admin/screens/admin/tenant_lifecycle_copy.dart';

void main() {
  test('tenant lifecycle copy reports exact partial revocation outcome', () {
    final message = TenantLifecycleCopy.result('Tenant suspended.', {
      'credential_revocation': {
        'complete': false,
        'refresh_tokens_revoked': 4,
        'sessions_revoked': 2,
        'results': [
          {'status': 'revoked'},
          {'status': 'failed', 'idempotency_key': 'tenant:t1:session:s2'},
        ],
      },
    });

    expect(message, contains('4 refresh tokens and 2 sessions'));
    expect(message, contains('1 credential operations failed'));
    expect(message, contains('idempotency keys'));
  });

  test('break-glass copy distinguishes exact partial credential outcome', () {
    final message = BreakGlassRevocationCopy.result({
      'retryable': true,
      'credential_results': [
        {'status': 'revoked', 'idempotency_key': 'break-glass:session:s1'},
        {'status': 'failed', 'idempotency_key': 'break-glass:token:t1'},
      ],
    });

    expect(message, contains('1 derived credentials were revoked'));
    expect(message, contains('1 failed'));
    expect(message, contains('idempotency keys'));
  });
}
