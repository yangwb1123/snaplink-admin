import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/form_validators.dart';

void main() {
  group('FormValidators', () {
    test('required passes with value', () {
      expect(FormValidators.required('hello'), isNull);
    });

    test('required fails with empty', () {
      expect(FormValidators.required(''), isNotEmpty);
    });

    test('required fails with null', () {
      expect(FormValidators.required(null), isNotEmpty);
    });

    test('required uses custom field name', () {
      final result = FormValidators.required('', 'Name');
      expect(result, contains('Name'));
    });

    test('hostname passes valid domain', () {
      expect(FormValidators.hostname('example.com'), isNull);
      expect(FormValidators.hostname('sub.domain.co.uk'), isNull);
    });

    test('hostname fails invalid domain', () {
      expect(FormValidators.hostname('not-a-domain'), isNotEmpty);
      expect(FormValidators.hostname(''), isNull); // empty = no error
    });

    test('url passes valid URL', () {
      expect(FormValidators.url('https://example.com/callback'), isNull);
      expect(FormValidators.url('http://localhost:8080'), isNull);
    });

    test('url fails invalid URL', () {
      expect(FormValidators.url('not-a-url'), isNotEmpty);
    });

    test('email passes valid email', () {
      expect(FormValidators.email('user@example.com'), isNull);
    });

    test('email fails invalid email', () {
      expect(FormValidators.email('not-an-email'), isNotEmpty);
    });

    test('minLength passes long enough', () {
      expect(FormValidators.minLength('hello', 3), isNull);
    });

    test('minLength fails too short', () {
      expect(FormValidators.minLength('ab', 3), isNotEmpty);
    });

    test('alphanumeric passes valid', () {
      expect(FormValidators.alphanumeric('client-id_01'), isNull);
    });

    test(
      'alphanumeric fails invalid chars',
      () => expect(FormValidators.alphanumeric('hello world!'), isNotEmpty),
    );
  });
}
