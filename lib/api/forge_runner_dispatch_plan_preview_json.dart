part of 'forge_runner_dispatch_plan_preview.dart';

// jsonDecode silently keeps the last value for duplicate object keys. Parse
// the object/array nesting before decoding so repeated candidate member names
// in separate array elements remain valid while a duplicate in one object is
// rejected.
void _rejectDuplicateObjectKeys(String source) {
  _DuplicateKeyScanner(source).scan();
}

class _DuplicateKeyScanner {
  final String source;
  var _index = 0;

  _DuplicateKeyScanner(this.source);

  void scan() {
    _parseValue();
    _skipWhitespace();
    if (_index != source.length) {
      throw const FormatException('trailing JSON value');
    }
  }

  void _parseValue() {
    _skipWhitespace();
    if (_index >= source.length) {
      throw const FormatException('missing JSON value');
    }
    switch (source[_index]) {
      case '{':
        _parseObject();
      case '[':
        _parseArray();
      case '"':
        _parseString();
      default:
        _parseScalar();
    }
  }

  void _parseObject() {
    _expect('{');
    _skipWhitespace();
    final keys = <String>{};
    if (_take('}')) return;
    while (true) {
      _skipWhitespace();
      final keyStart = _index;
      final keyEnd = _parseString();
      final key = jsonDecode(source.substring(keyStart, keyEnd)) as String;
      if (!keys.add(key)) {
        throw FormatException('duplicate object key: $key');
      }
      _skipWhitespace();
      _expect(':');
      _parseValue();
      _skipWhitespace();
      if (_take('}')) return;
      _expect(',');
    }
  }

  void _parseArray() {
    _expect('[');
    _skipWhitespace();
    if (_take(']')) return;
    while (true) {
      _parseValue();
      _skipWhitespace();
      if (_take(']')) return;
      _expect(',');
    }
  }

  int _parseString() {
    _expect('"');
    var escaped = false;
    while (_index < source.length) {
      final char = source[_index++];
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        return _index;
      }
    }
    throw const FormatException('unterminated JSON string');
  }

  void _parseScalar() {
    final start = _index;
    while (_index < source.length && !' \t\r\n,]}'.contains(source[_index])) {
      _index++;
    }
    if (start == _index) {
      throw const FormatException('invalid JSON scalar');
    }
  }

  void _skipWhitespace() {
    while (_index < source.length && ' \t\r\n'.contains(source[_index])) {
      _index++;
    }
  }

  bool _take(String expected) {
    if (_index < source.length && source[_index] == expected) {
      _index++;
      return true;
    }
    return false;
  }

  void _expect(String expected) {
    if (!_take(expected)) {
      throw FormatException('expected JSON $expected');
    }
  }
}
