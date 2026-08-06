import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/admin_oauth_resources.dart';

void main() {
  test('parses, trims, and de-duplicates configured resources', () {
    expect(
      AdminOAuthResources.parse(
        ' https://billing.example ,stripe-adapter-api,https://billing.example ',
      ),
      ['https://billing.example', 'stripe-adapter-api'],
    );
  });

  test('allows an empty list for a profile without commerce services', () {
    expect(AdminOAuthResources.parse(' , '), isEmpty);
  });

  test('rejects whitespace inside a resource indicator', () {
    expect(
      () => AdminOAuthResources.parse('billing-api,bad resource'),
      throwsFormatException,
    );
  });
}
