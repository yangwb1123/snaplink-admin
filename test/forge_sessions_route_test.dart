import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/product_entry_route.dart';

void main() {
  test('routes Forge Sessions root and deep links independently', () {
    expect(productEntryForPath('/forge'), ProductEntry.forgeSessions);
    expect(productEntryForPath('/forge/'), ProductEntry.forgeSessions);
    expect(
      productEntryForPath('/forge/conversations/c-1'),
      ProductEntry.forgeSessions,
    );
    expect(productEntryForPath('/agent/'), ProductEntry.agentOperations);
  });

  test('does not route lookalike Forge prefixes', () {
    expect(productEntryForPath('/forge-evil'), ProductEntry.login);
    expect(productEntryForPath('/forger'), ProductEntry.login);
  });
}
