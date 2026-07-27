import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/change_approval_models.dart';

void main() {
  test('normalizes Go PascalCase fields and base64 encoded byte payload', () {
    final payload = base64Encode(
      utf8.encode(jsonEncode({'tenant_id': 'tenant-1', 'enabled': false})),
    );

    final normalized = normalizeChangeApproval({
      'ID': 'change-1',
      'ActionType': 'tenant.update',
      'Payload': payload,
      'ProposedBy': 'operator-1',
      'Status': 'pending',
      'CreatedAt': '2026-07-27T00:00:00Z',
    });

    expect(normalized['id'], 'change-1');
    expect(normalized['action_type'], 'tenant.update');
    expect(normalized['payload'], {'tenant_id': 'tenant-1', 'enabled': false});
    expect(normalized['proposed_by'], 'operator-1');
  });

  test('never exposes an undecodable raw payload', () {
    const raw = '%%%raw-sensitive-payload%%%';
    final normalized = normalizeChangeApproval({
      'id': 'change-2',
      'payload': raw,
    });

    expect(normalized['payload'], contains('_unavailable'));
    expect(normalized.toString(), isNot(contains(raw)));
  });
}
