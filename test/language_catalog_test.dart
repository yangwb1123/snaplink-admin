import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/language_catalog.dart';

void main() {
  group('parseLanguageOptions', () {
    test('parses comma-separated BCP-47 tags in declared order', () {
      final options = parseLanguageOptions('en,zh,ja');
      expect(options.map((l) => l.languageCode).toList(), ['en', 'zh', 'ja']);
    });

    test('trims whitespace and drops empty segments', () {
      final options = parseLanguageOptions(' en , zh ,');
      expect(options.map((l) => l.languageCode).toList(), ['en', 'zh']);
    });

    test('deduplicates repeated tags', () {
      final options = parseLanguageOptions('en,en,zh,EN');
      expect(options.length, 2);
    });

    test('keeps script and region segments', () {
      final options = parseLanguageOptions('zh-Hans-CN,pt-BR');
      expect(options[0].scriptCode, 'Hans');
      expect(options[0].countryCode, 'CN');
      expect(options[1].countryCode, 'BR');
    });

    test('falls back to defaults for absent, empty, or invalid input', () {
      expect(parseLanguageOptions(null), defaultLanguageOptions);
      expect(parseLanguageOptions(''), defaultLanguageOptions);
      expect(parseLanguageOptions('   '), defaultLanguageOptions);
      expect(parseLanguageOptions('!!!,123'), defaultLanguageOptions);
    });

    test('drops invalid tags but keeps valid ones', () {
      final options = parseLanguageOptions('en,!!!,zh');
      expect(options.map((l) => l.languageCode).toList(), ['en', 'zh']);
    });
  });

  group('languageOptionsIncludingCurrent', () {
    test('returns options unchanged when the current locale is present', () {
      const options = [Locale('en'), Locale('zh')];
      expect(
        languageOptionsIncludingCurrent(options, const Locale('zh')),
        same(options),
      );
    });

    test('appends the current locale when absent (dropdown value safety)', () {
      const options = [Locale('en'), Locale('zh')];
      final result = languageOptionsIncludingCurrent(
        options,
        const Locale('ja'),
      );
      expect(result.last.languageCode, 'ja');
      expect(result.length, 3);
    });
  });

  group('languageOptionLabel', () {
    test('uses known labels and uppercased fallback', () {
      expect(languageOptionLabel(const Locale('en')), 'English');
      expect(languageOptionLabel(const Locale('zh')), '中文');
      expect(languageOptionLabel(const Locale('ja')), '日本語');
      expect(languageOptionLabel(const Locale('xx')), 'XX');
    });
  });

  group('isValidLanguageTag', () {
    test('accepts BCP-47 tags and rejects garbage', () {
      expect(isValidLanguageTag('en'), isTrue);
      expect(isValidLanguageTag('zh-Hans-CN'), isTrue);
      expect(isValidLanguageTag('pt-BR'), isTrue);
      expect(isValidLanguageTag('!'), isFalse);
      expect(isValidLanguageTag(''), isFalse);
      expect(isValidLanguageTag('1abc'), isFalse);
      expect(isValidLanguageTag('a'), isFalse);
    });
  });

  group('flagEmojiForLocale', () {
    test('maps regions to regional-indicator flags', () {
      expect(
        flagEmojiForLocale(
          const Locale.fromSubtags(languageCode: 'pt', countryCode: 'BR'),
        ),
        '🇧🇷',
      );
      expect(
        flagEmojiForLocale(
          const Locale.fromSubtags(languageCode: 'en', countryCode: 'US'),
        ),
        '🇺🇸',
      );
      expect(
        flagEmojiForLocale(
          const Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
        ),
        '🇹🇼',
      );
    });

    test('maps bare language codes from the table', () {
      expect(flagEmojiForLocale(const Locale('en')), '🇬🇧');
      expect(flagEmojiForLocale(const Locale('zh')), '🇨🇳');
      expect(flagEmojiForLocale(const Locale('ja')), '🇯🇵');
      expect(flagEmojiForLocale(const Locale('ko')), '🇰🇷');
    });

    test('falls back to a globe for unknown languages', () {
      expect(flagEmojiForLocale(const Locale('xx')), '🌐');
    });
  });
}
