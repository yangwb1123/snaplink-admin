part of 'forge_scheduler_selection_preview.dart';

/// Bounded duplicate-key scanner. `jsonDecode` otherwise keeps the last
/// occurrence, which would make an authority mutation indistinguishable from
/// a valid response.
class _SchedulerDuplicateScanner {
  final String source;
  final List<Set<String>> _objects = <Set<String>>[];

  _SchedulerDuplicateScanner(this.source);

  void scan() {
    var inString = false;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        final start = index;
        index++;
        var stringEscaped = false;
        for (; index < source.length; index++) {
          final current = source[index];
          if (stringEscaped) {
            stringEscaped = false;
          } else if (current == r'\') {
            stringEscaped = true;
          } else if (current == '"') {
            break;
          }
        }
        final end = index + 1;
        var next = end;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (_objects.isEmpty) {
            throw const FormatException('Forge scheduler key outside object.');
          }
          final key = jsonDecode(source.substring(start, end)) as String;
          if (!_objects.last.add(key)) {
            throw const FormatException(
              'Duplicate Forge scheduler selection key.',
            );
          }
        }
        inString = false;
        continue;
      }
      if (char == '{') _objects.add(<String>{});
      if (char == '}') {
        if (_objects.isEmpty) {
          throw const FormatException('Unbalanced Forge scheduler object.');
        }
        _objects.removeLast();
      }
    }
    if (inString || _objects.isNotEmpty) {
      throw const FormatException('Unbalanced Forge scheduler JSON.');
    }
  }
}
