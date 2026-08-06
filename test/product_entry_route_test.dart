import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/product_entry_route.dart';

void main() {
  test('classifies each product root and deep link', () {
    expect(productEntryForPath('/'), ProductEntry.login);
    expect(productEntryForPath('/login/'), ProductEntry.login);
    expect(productEntryForPath('/setup/complete'), ProductEntry.setup);
    expect(productEntryForPath('/portal/security'), ProductEntry.portal);
    expect(productEntryForPath('/developer/manage'), ProductEntry.developer);
    expect(
      productEntryForPath('/device/verify/complete'),
      ProductEntry.deviceVerification,
    );
    expect(productEntryForPath('/admin/users/alice'), ProductEntry.admin);
  });

  test('rejects lookalike product prefixes', () {
    expect(productEntryForPath('/administrator'), ProductEntry.login);
    expect(productEntryForPath('/portal-evil'), ProductEntry.login);
    expect(productEntryForPath('/setup.example'), ProductEntry.login);
    expect(productEntryForPath('/device/verification'), ProductEntry.login);
  });
}
