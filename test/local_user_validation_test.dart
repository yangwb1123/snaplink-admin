import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/local_user_validation.dart';

void main() {
  test('matches Snaplink local username constraints', () {
    expect(validateSnaplinkLocalUsername('alice-01'), isNull);
    expect(validateSnaplinkLocalUsername('1alice'), isNotNull);
    expect(validateSnaplinkLocalUsername('ab'), isNotNull);
    expect(validateSnaplinkLocalUsername('alice@example'), isNotNull);
  });

  test('matches Snaplink local password constraints', () {
    expect(validateSnaplinkInitialPassword('abc12345'), isNull);
    expect(validateSnaplinkInitialPassword('abcdefgh'), isNotNull);
    expect(validateSnaplinkInitialPassword('12345678'), isNotNull);
    expect(validateSnaplinkInitialPassword('a1'), isNotNull);
  });

  test('matches Snaplink local email constraints', () {
    expect(validateSnaplinkLocalEmail('alice@example.com'), isNull);
    expect(validateSnaplinkLocalEmail('alice@example'), isNotNull);
    expect(validateSnaplinkLocalEmail('alice@'), isNotNull);
  });
}
