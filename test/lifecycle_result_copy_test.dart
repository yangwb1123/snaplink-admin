import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/break_glass_widgets.dart';
import 'package:sso_admin/screens/admin/tenant_lifecycle_copy.dart';

void main() {
  test('tenant lifecycle copy reports exact partial revocation outcome', () {
    final copy = TenantLifecycleCopy.resultCopy('Tenant suspended.', {
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

    expect(
      copy.key,
      contains('{refreshTokens} refresh tokens and {sessions} sessions'),
    );
    expect(copy.args, containsPair('refreshTokens', 4));
    expect(copy.args, containsPair('sessions', 2));
    expect(copy.args, containsPair('failed', 1));
  });

  test('break-glass copy distinguishes exact partial credential outcome', () {
    final copy = BreakGlassRevocationCopy.resultCopy({
      'retryable': true,
      'credential_results': [
        {'status': 'revoked', 'idempotency_key': 'break-glass:session:s1'},
        {'status': 'failed', 'idempotency_key': 'break-glass:token:t1'},
      ],
    });

    expect(copy.key, contains('{revoked} derived credentials were revoked'));
    expect(copy.args, containsPair('revoked', 1));
    expect(copy.args, containsPair('failed', 1));
  });
}
