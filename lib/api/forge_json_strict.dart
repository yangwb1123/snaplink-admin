import 'dart:convert';

/// Rejects duplicate object members before Dart's JSON decoder can silently
/// keep the last value. Forge contracts are owner scoped, so duplicate fields
/// are ambiguous input and must fail closed at every object depth.
void rejectDuplicateForgeJsonKeys(String body) {
  _ForgeJsonDuplicateKeyScanner(body).scan();
}

class _ForgeJsonDuplicateKeyScanner {
  final String _body;
  var _index = 0;

  _ForgeJsonDuplicateKeyScanner(this._body);

  void scan() {
    _skipWhitespace();
    _scanValue();
    _skipWhitespace();
    if (_index != _body.length) {
      throw const FormatException('Forge returned invalid JSON.');
    }
  }

  void _scanValue() {
    if (_index >= _body.length) {
      throw const FormatException('Forge returned invalid JSON.');
    }
    switch (_body[_index]) {
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
    _index++;
    _skipWhitespace();
    final keys = <String>{};
    if (_consume('}')) return;
    while (true) {
      if (_index >= _body.length || _body[_index] != '"') {
        throw const FormatException('Forge returned invalid JSON.');
      }
      final key = _scanString();
      if (!keys.add(key)) {
        throw const FormatException('Forge returned duplicate JSON fields.');
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
    _index++;
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
    final start = _index;
    _expect('"');
    while (_index < _body.length) {
      final character = _body[_index++];
      if (character == '"') {
        final decoded = jsonDecode(_body.substring(start, _index));
        if (decoded is! String) {
          throw const FormatException('Forge returned invalid JSON.');
        }
        return decoded;
      }
      if (character == '\\') {
        if (_index >= _body.length) {
          throw const FormatException('Forge returned invalid JSON.');
        }
        final escape = _body[_index++];
        if (escape == 'u') {
          if (_index + 4 > _body.length ||
              !RegExp(
                r'^[0-9a-fA-F]{4}$',
              ).hasMatch(_body.substring(_index, _index + 4))) {
            throw const FormatException('Forge returned invalid JSON.');
          }
          _index += 4;
        } else if (!'"\\/bfnrt'.contains(escape)) {
          throw const FormatException('Forge returned invalid JSON.');
        }
      } else if (character.codeUnitAt(0) < 0x20) {
        throw const FormatException('Forge returned invalid JSON.');
      }
    }
    throw const FormatException('Forge returned invalid JSON.');
  }

  void _scanLiteral(String literal) {
    if (!_body.startsWith(literal, _index)) {
      throw const FormatException('Forge returned invalid JSON.');
    }
    _index += literal.length;
  }

  void _scanNumber() {
    final start = _index;
    if (_consume('-')) {}
    if (_consume('0')) {
      // A leading zero may not be followed by another digit.
      if (_index < _body.length && _isDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
    } else {
      if (_index >= _body.length || !_isNonZeroDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
      while (_index < _body.length && _isDigit(_body[_index])) _index++;
    }
    if (_consume('.')) {
      if (_index >= _body.length || !_isDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
      while (_index < _body.length && _isDigit(_body[_index])) _index++;
    }
    if (_index < _body.length &&
        (_body[_index] == 'e' || _body[_index] == 'E')) {
      _index++;
      if (_index < _body.length &&
          (_body[_index] == '+' || _body[_index] == '-')) {
        _index++;
      }
      if (_index >= _body.length || !_isDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
      while (_index < _body.length && _isDigit(_body[_index])) _index++;
    }
    if (start == _index) {
      throw const FormatException('Forge returned invalid JSON.');
    }
  }

  void _skipWhitespace() {
    while (_index < _body.length && ' \t\r\n'.contains(_body[_index])) {
      _index++;
    }
  }

  bool _consume(String expected) {
    if (_index < _body.length && _body[_index] == expected) {
      _index++;
      return true;
    }
    return false;
  }

  void _expect(String expected) {
    if (!_consume(expected)) {
      throw const FormatException('Forge returned invalid JSON.');
    }
  }

  bool _isDigit(String value) =>
      value.codeUnitAt(0) >= 0x30 && value.codeUnitAt(0) <= 0x39;

  bool _isNonZeroDigit(String value) =>
      value.codeUnitAt(0) >= 0x31 && value.codeUnitAt(0) <= 0x39;
}
