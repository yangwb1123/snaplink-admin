@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/command_palette_commands.dart';

void main() {
  final uiFiles = [Directory('lib/screens'), Directory('lib/widgets')]
      .expand((directory) => directory.listSync(recursive: true))
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);

  test('feature screens do not render literal copy with raw Text', () {
    final violations = <String>{};
    final rawText = RegExp('\\bText\\(\\s*($_literalSequence)');
    final rawProperty = RegExp(
      '(?:labelText|hintText|helperText|tooltip|semanticsLabel):'
      '\\s*($_literalSequence)\\s*[,)]',
    );
    for (final file in uiFiles) {
      final source = file.readAsStringSync();
      for (final match in rawText.allMatches(source)) {
        final text = _readLiteralSequence(match.group(1)!);
        if (!_isTechnicalCopy(text)) {
          violations.add('${file.path}: $text');
        }
      }
      for (final match in rawProperty.allMatches(source)) {
        final text = _readLiteralSequence(match.group(1)!);
        if (!_isTechnicalCopy(text)) {
          violations.add('${file.path}: $text');
        }
      }
      for (final argument in _firstCallArguments(source, 'Text')) {
        if (argument.contains('context.tr(')) continue;
        for (final text in _visibleExpressionLiterals(argument)) {
          if (!_isTechnicalCopy(text)) {
            violations.add('${file.path}: $text');
          }
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: (violations.toList()..sort()).join('\n'),
    );
  });

  test('static localized copy has a Chinese translation', () {
    final chinese = AppStrings.forLocale(const Locale('zh'));
    final missing = <String>{};
    final localizedCall = RegExp(
      '(?:LocalizedText\\(\\s*|context\\.tr\\(\\s*)($_literalSequence)',
    );
    final localizedProperty = RegExp('($_literalSequence)\\.localized');
    final messageAssignment = RegExp(
      '\\b[_A-Za-z0-9]*(?:error|message|notice|warning)'
      '[_A-Za-z0-9]*\\s*=\\s*($_literalSequence)\\s*[,;]',
      caseSensitive: false,
    );
    final localizedHelperFirst = RegExp(
      '(?:_infoRow|_metric|_jsonResult|_reportCard|_recoveryStatus|_warning)'
      '\\(\\s*($_literalSequence)',
    );
    final localizedContextHelper = RegExp(
      '(?:_card|_section|_sectionTitle)'
      '\\(\\s*context\\s*,\\s*($_literalSequence)',
    );
    final localizedFieldLabel = RegExp(
      '_field\\(\\s*$_literalSequence\\s*,\\s*($_literalSequence)',
    );
    final localizedNamedCopy = RegExp(
      '(?:title|detail|body|emptyText):\\s*($_literalSequence)\\s*[,)]',
    );
    for (final file in uiFiles) {
      final source = file.readAsStringSync();
      final matches = <RegExpMatch>[
        ...localizedCall.allMatches(source),
        ...localizedProperty.allMatches(source),
        ...messageAssignment.allMatches(source),
        ...localizedHelperFirst.allMatches(source),
        ...localizedContextHelper.allMatches(source),
        ...localizedFieldLabel.allMatches(source),
        ...localizedNamedCopy.allMatches(source),
      ];
      for (final match in matches) {
        final text = _readLiteralSequence(match.group(1)!);
        if (text.isEmpty ||
            !RegExp('[A-Za-z]').hasMatch(text) ||
            _isTechnicalCopy(text)) {
          continue;
        }
        if (chinese.translate(text) == text) missing.add('${file.path}: $text');
      }
      for (final constructor in const ['LocalizedText', 'context.tr']) {
        for (final argument in _firstCallArguments(source, constructor)) {
          for (final text in _visibleExpressionLiterals(argument)) {
            if (text.isEmpty ||
                !RegExp('[A-Za-z]').hasMatch(text) ||
                _isTechnicalCopy(text)) {
              continue;
            }
            if (chinese.translate(text) == text) {
              missing.add('${file.path}: $text');
            }
          }
        }
      }
    }
    expect(missing, isEmpty, reason: (missing.toList()..sort()).join('\n'));
  });

  test('command palette titles have a Chinese translation', () {
    final chinese = AppStrings.forLocale(const Locale('zh'));
    final missing = commandPaletteItems
        .map((item) => item.title)
        .where((title) => chinese.translate(title) == title)
        .toList(growable: false);
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}

const _literalAtom = r'''(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")''';
const _literalSequence = '(?:$_literalAtom\\s*)+';

String _readLiteralSequence(String source) {
  final parts = RegExp(_literalAtom).allMatches(source).map((match) {
    final quoted = match.group(0)!;
    return quoted
        .substring(1, quoted.length - 1)
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\\', r'\');
  });
  return parts.join();
}

Iterable<String> _visibleExpressionLiterals(String expression) sync* {
  final visible = RegExp('(?:^|\\?\\?|[?:])\\s*($_literalSequence)');
  for (final match in visible.allMatches(expression)) {
    yield _readLiteralSequence(match.group(1)!);
  }
}

Iterable<String> _firstCallArguments(String source, String call) sync* {
  final needle = '$call(';
  var searchFrom = 0;
  while (true) {
    final start = source.indexOf(needle, searchFrom);
    if (start < 0) return;
    searchFrom = start + needle.length;
    if (start > 0 &&
        RegExp('[A-Za-z0-9_]').hasMatch(source.substring(start - 1, start))) {
      continue;
    }

    final open = start + call.length;
    var depth = 1;
    String? quote;
    var escaped = false;
    for (var index = open + 1; index < source.length; index++) {
      final char = source[index];
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == quote) {
          quote = null;
        }
        continue;
      }
      if (char == "'" || char == '"') {
        quote = char;
      } else if (char == '(' || char == '[' || char == '{') {
        depth++;
      } else if (char == ')' || char == ']' || char == '}') {
        depth--;
        if (depth == 0) {
          yield source.substring(open + 1, index);
          break;
        }
      } else if (char == ',' && depth == 1) {
        yield source.substring(open + 1, index);
        break;
      }
    }
  }
}

bool _isTechnicalCopy(String value) {
  final text = value.trim();
  if (text.isEmpty ||
      !RegExp('[A-Za-z]').hasMatch(text) ||
      RegExp(r'^[0-9.]+$').hasMatch(text) ||
      RegExp(
        r'^(GET|POST|PUT|PATCH|DELETE|OIDC|SAML|SCIM|JSON|jwt|session)$',
      ).hasMatch(text) ||
      text.startsWith('http') ||
      text.startsWith('#') ||
      text.startsWith('{') ||
      text.contains(r'$') ||
      text.contains('@') ||
      text.startsWith('e.g.') ||
      text.startsWith('example.com') ||
      text.startsWith('api.internal.') ||
      text.contains(r'\n') ||
      text.contains('admin:read') ||
      text == 'ID' ||
      text == '1-based' ||
      text == 'BulkRequest JSON' ||
      text == 'ETag' ||
      text == 'Webhook URL' ||
      text == 'YYYY-MM-DD' ||
      text == 'Windows, macOS, iOS…' ||
      text == 'client_secret, signing_key, etc.' ||
      text == 'user.created, session.revoked' ||
      text == 'acme' ||
      text == 'acme-okta' ||
      text == 'INC-12345' ||
      text == 'true' ||
      text == 'false' ||
      text == 'code' ||
      text == 'English' ||
      text == '中文' ||
      text == 'XXXX-XXXX' ||
      text == 'admin') {
    return true;
  }
  return false;
}
