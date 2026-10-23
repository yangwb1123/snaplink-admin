import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/format_helpers.dart';

void main() {
  group('formatCount finite values', () {
    test('renders zero and small counts without grouping', () {
      expect(formatCount(0), '0');
      expect(formatCount(0.0), '0');
      expect(formatCount('0'), '0');
      expect(formatCount(7), '7');
      expect(formatCount(999), '999');
    });

    test('groups thousands with commas', () {
      expect(formatCount(1000), '1,000');
      expect(formatCount(1234567), '1,234,567');
      expect(formatCount('1234567'), '1,234,567');
    });

    test('rounds half away from zero at the 1,000 boundary', () {
      expect(formatCount(999.4), '999');
      expect(formatCount(999.5), '1,000');
    });

    test('keeps the sign for negative values and rounds away from zero', () {
      expect(formatCount(-999), '-999');
      expect(formatCount(-1234.4), '-1,234');
      expect(formatCount(-1234.6), '-1,235');
      expect(formatCount(-999.5), '-1,000');
    });
  });

  group('formatCount invalid input fallbacks', () {
    test('returns the default fallback for null and unparseable input', () {
      expect(formatCount(null), '—');
      expect(formatCount(''), '—');
      expect(formatCount('not-a-number'), '—');
      expect(formatCount(true), '—');
    });

    test('returns an explicit fallback for null and unparseable input', () {
      expect(formatCount(null, fallback: '0'), '0');
      expect(formatCount('not-a-number', fallback: 'n/a'), 'n/a');
    });
  });

  group('formatCount non-finite values', () {
    test('returns the default fallback for NaN', () {
      expect(formatCount(double.nan), '—');
    });

    test('returns the default fallback for positive infinity', () {
      expect(formatCount(double.infinity), '—');
    });

    test('returns the default fallback for negative infinity', () {
      expect(formatCount(-double.infinity), '—');
    });

    test('returns the default fallback for parsed NaN', () {
      expect(formatCount('NaN'), '—');
    });

    test('returns the default fallback for parsed positive infinity', () {
      expect(formatCount('Infinity'), '—');
    });

    test('returns the default fallback for parsed negative infinity', () {
      expect(formatCount('-Infinity'), '—');
    });

    test('returns the default fallback for a parsed overflow literal', () {
      expect(formatCount('1e309'), '—');
    });

    test('returns an explicit fallback for non-finite input', () {
      expect(formatCount(double.nan, fallback: '0'), '0');
      expect(formatCount(double.infinity, fallback: 'n/a'), 'n/a');
      expect(formatCount(-double.infinity, fallback: 'n/a'), 'n/a');
      expect(formatCount('NaN', fallback: 'n/a'), 'n/a');
      expect(formatCount('Infinity', fallback: '0'), '0');
      expect(formatCount('-Infinity', fallback: '0'), '0');
      expect(formatCount('1e309', fallback: 'n/a'), 'n/a');
    });
  });
}
