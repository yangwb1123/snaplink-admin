part of 'forge_execution_reconciliation_observation.dart';

/// Minimal JSON grammar scanner for duplicate object member names. It does
/// not replace `jsonDecode`; it only prevents last-key-wins ambiguity first.
void _reconciliationRejectDuplicateJsonKeys(String source) {
  _ReconciliationDuplicateScanner(source).scan();
}

class _ReconciliationDuplicateScanner {
  final String source;
  var index = 0;

  _ReconciliationDuplicateScanner(this.source);

  void scan() {
    _skipWhitespace();
    _scanValue();
    _skipWhitespace();
    if (index != source.length) {
      throw const FormatException(
        'Invalid Forge execution reconciliation JSON.',
      );
    }
  }

  void _scanValue() {
    if (index >= source.length) _invalid();
    switch (source[index]) {
      case '{':
        _scanObject();
      case '[':
        _scanArray();
      case '"':
        _scanString();
      case 't':
        _scanLiteral('true');
      case 'f':
        _scanLiteral('false');
      case 'n':
        _scanLiteral('null');
      default:
        _scanNumber();
    }
  }

  void _scanObject() {
    index++;
    _skipWhitespace();
    final keys = <String>{};
    if (_consume('}')) return;
    while (true) {
      if (index >= source.length || source[index] != '"') _invalid();
      final key = _scanString();
      if (!keys.add(key)) {
        throw const FormatException(
          'Forge execution reconciliation JSON contains duplicate fields.',
        );
      }
      _skipWhitespace();
      _expect(':');
      _skipWhitespace();
      _scanValue();
      _skipWhitespace();
      if (_consume('}')) return;
      _expect(',');
      _skipWhitespace();
    }
  }

  void _scanArray() {
    index++;
    _skipWhitespace();
    if (_consume(']')) return;
    while (true) {
      _scanValue();
      _skipWhitespace();
      if (_consume(']')) return;
      _expect(',');
      _skipWhitespace();
    }
  }

  String _scanString() {
    final start = index;
    _expect('"');
    while (index < source.length) {
      final character = source[index++];
      if (character == '"') {
        final decoded = jsonDecode(source.substring(start, index));
        if (decoded is! String) _invalid();
        return decoded;
      }
      if (character == '\\') {
        if (index >= source.length) _invalid();
        final escaped = source[index++];
        if (escaped == 'u') {
          if (index + 4 > source.length) _invalid();
          for (var digit = 0; digit < 4; digit++) {
            if (!_isHex(source[index++])) _invalid();
          }
        } else if (!'"\\/bfnrt'.contains(escaped)) {
          _invalid();
        }
      } else if (character.codeUnitAt(0) < 0x20) {
        _invalid();
      }
    }
    _invalid();
  }

  void _scanLiteral(String literal) {
    if (!source.startsWith(literal, index)) _invalid();
    index += literal.length;
  }

  void _scanNumber() {
    final start = index;
    _consume('-');
    if (index >= source.length) _invalid();
    if (_consume('0')) {
      if (index < source.length && _isDigit(source[index])) _invalid();
    } else {
      if (index >= source.length || !_isNonZeroDigit(source[index])) _invalid();
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
    }
    if (_consume('.')) {
      if (index >= source.length || !_isDigit(source[index])) _invalid();
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
    }
    if (index < source.length &&
        (source[index] == 'e' || source[index] == 'E')) {
      index++;
      if (index < source.length &&
          (source[index] == '+' || source[index] == '-')) {
        index++;
      }
      if (index >= source.length || !_isDigit(source[index])) _invalid();
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
    }
    if (start == index) _invalid();
  }

  void _skipWhitespace() {
    while (index < source.length && ' \t\r\n'.contains(source[index])) {
      index++;
    }
  }

  bool _consume(String character) {
    if (index < source.length && source[index] == character) {
      index++;
      return true;
    }
    return false;
  }

  void _expect(String character) {
    if (!_consume(character)) _invalid();
  }

  bool _isDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  bool _isNonZeroDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 0x31 && code <= 0x39;
  }

  bool _isHex(String value) {
    final code = value.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x46) ||
        (code >= 0x61 && code <= 0x66);
  }

  Never _invalid() => throw const FormatException(
    'Invalid Forge execution reconciliation JSON.',
  );
}
