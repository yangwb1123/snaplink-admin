part of 'app_strings.dart';

/// Source-string translation for page-specific copy.
extension AppStringsSourceLookup on AppStrings {
  String translate(
    String source, [
    Map<String, Object?> values = const <String, Object?>{},
  ]) {
    final language = locale.languageCode;
    var result = language == 'en'
        ? source
        : AppStrings._sourceTranslations[language]?[source] ??
              _matchSourcePattern(language, source) ??
              source;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return result;
  }
}

/// Concise page-level access that still follows Flutter's active locale.
extension AppStringsBuildContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);

  String tr(
    String source, [
    Map<String, Object?> values = const <String, Object?>{},
  ]) => AppStrings.of(this).translate(source, values);
}

String? _matchSourcePattern(String language, String source) {
  for (final pattern in _sourcePatterns[language] ?? const []) {
    final match = pattern.expression.firstMatch(source);
    if (match == null) continue;
    var result = pattern.translation;
    for (var index = 0; index < pattern.names.length; index++) {
      final captured = match.group(index + 1) ?? '';
      final localizedCapture =
          AppStrings._sourceTranslations[language]?[captured] ??
          _matchSourcePattern(language, captured) ??
          captured;
      result = result.replaceAll('{${pattern.names[index]}}', localizedCapture);
    }
    return result;
  }
  return null;
}

final _sourcePatterns = <String, List<_SourcePattern>>{
  for (final language in AppStrings._sourceTranslations.keys)
    language: _buildSourcePatterns(language),
};

List<_SourcePattern> _buildSourcePatterns(String language) {
  final patterns = [
    for (final entry in AppStrings._sourceTranslations[language]!.entries)
      if (entry.key.contains('{')) _SourcePattern(entry.key, entry.value),
  ];
  patterns.sort((left, right) => right.specificity.compareTo(left.specificity));
  return patterns;
}

class _SourcePattern {
  final List<String> names;
  final RegExp expression;
  final int specificity;
  final String translation;

  _SourcePattern(String source, this.translation)
    : names = RegExp(
        r'\{([a-zA-Z][a-zA-Z0-9_]*)\}',
      ).allMatches(source).map((match) => match.group(1)!).toList(),
      expression = RegExp(
        '^${source.splitMapJoin(RegExp(r'\{[a-zA-Z][a-zA-Z0-9_]*\}'), onMatch: (_) => r'([\s\S]*?)', onNonMatch: RegExp.escape)}\$',
      ),
      specificity = source.length;
}
