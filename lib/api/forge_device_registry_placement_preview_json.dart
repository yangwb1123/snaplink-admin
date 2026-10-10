part of 'forge_device_registry_placement_preview.dart';

/// Detect repeated JSON object members before Dart's decoder overwrites one.
void _rejectDuplicateRegistryPlacementKeys(String source) {
  _RegistryPlacementDuplicateScanner(source).scan();
}

class _RegistryPlacementDuplicateScanner {
  final String source;
  var index = 0;

  _RegistryPlacementDuplicateScanner(this.source);

  void scan() {
    _space();
    _value();
    _space();
    if (index != source.length) {
      throw const FormatException('Invalid JSON.');
    }
  }

  void _value() {
    if (index >= source.length) throw const FormatException('Invalid JSON.');
    switch (source[index]) {
      case '{':
        _object();
      case '[':
        _array();
      case '"':
        _string();
      case 't':
        _literal('true');
      case 'f':
        _literal('false');
      case 'n':
        _literal('null');
      default:
        _number();
    }
  }

  void _object() {
    index++;
    _space();
    final keys = <String>{};
    if (_consume('}')) return;
    while (true) {
      if (index >= source.length || source[index] != '"') {
        throw const FormatException('Invalid JSON.');
      }
      final key = _string();
      if (!keys.add(key)) throw const FormatException('Duplicate JSON key.');
      _space();
      _expect(':');
      _space();
      _value();
      _space();
      if (_consume('}')) return;
      _expect(',');
      _space();
    }
  }

  void _array() {
    index++;
    _space();
    if (_consume(']')) return;
    while (true) {
      _value();
      _space();
      if (_consume(']')) return;
      _expect(',');
      _space();
    }
  }

  String _string() {
    final start = index;
    _expect('"');
    while (index < source.length) {
      final character = source[index++];
      if (character == '"') {
        final decoded = jsonDecode(source.substring(start, index));
        if (decoded is! String) throw const FormatException('Invalid JSON.');
        return decoded;
      }
      if (character == '\\') {
        if (index >= source.length) {
          throw const FormatException('Invalid JSON.');
        }
        final escaped = source[index++];
        if (escaped == 'u') {
          if (index + 4 > source.length) {
            throw const FormatException('Invalid JSON.');
          }
          for (var digit = 0; digit < 4; digit++) {
            if (!_hex(source[index++])) {
              throw const FormatException('Invalid JSON.');
            }
          }
        } else if (!'"\\/bfnrt'.contains(escaped)) {
          throw const FormatException('Invalid JSON.');
        }
      } else if (character.codeUnitAt(0) < 0x20) {
        throw const FormatException('Invalid JSON.');
      }
    }
    throw const FormatException('Invalid JSON.');
  }

  void _literal(String literal) {
    if (!source.startsWith(literal, index)) {
      throw const FormatException('Invalid JSON.');
    }
    index += literal.length;
  }

  void _number() {
    final start = index;
    if (_consume('-') && index >= source.length) {
      throw const FormatException('Invalid JSON.');
    }
    if (_consume('0')) {
      if (index < source.length && _digit(source[index])) {
        throw const FormatException('Invalid JSON.');
      }
    } else {
      if (index >= source.length || !_nonZeroDigit(source[index])) {
        throw const FormatException('Invalid JSON.');
      }
      while (index < source.length && _digit(source[index])) {
        index++;
      }
    }
    if (_consume('.')) {
      if (index >= source.length || !_digit(source[index])) {
        throw const FormatException('Invalid JSON.');
      }
      while (index < source.length && _digit(source[index])) {
        index++;
      }
    }
    if (index < source.length && 'eE'.contains(source[index])) {
      index++;
      if (index < source.length && '+-'.contains(source[index])) {
        index++;
      }
      if (index >= source.length || !_digit(source[index])) {
        throw const FormatException('Invalid JSON.');
      }
      while (index < source.length && _digit(source[index])) {
        index++;
      }
    }
    if (start == index) throw const FormatException('Invalid JSON.');
  }

  void _space() {
    while (index < source.length && ' \t\r\n'.contains(source[index])) {
      index++;
    }
  }

  bool _consume(String value) {
    if (index < source.length && source[index] == value) {
      index++;
      return true;
    }
    return false;
  }

  void _expect(String value) {
    if (!_consume(value)) throw const FormatException('Invalid JSON.');
  }

  static bool _digit(String value) =>
      value.codeUnitAt(0) >= 0x30 && value.codeUnitAt(0) <= 0x39;
  static bool _nonZeroDigit(String value) =>
      value.codeUnitAt(0) >= 0x31 && value.codeUnitAt(0) <= 0x39;
  static bool _hex(String value) => '0123456789abcdefABCDEF'.contains(value);
}
