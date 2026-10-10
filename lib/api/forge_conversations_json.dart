part of 'forge_conversations_api.dart';

bool _validRunRequestID(String value) =>
    value.trim().isNotEmpty &&
    utf8.encode(value).length <= 128 &&
    !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

bool _validConversationRequestID(String value) =>
    _validRunRequestID(value) && !value.contains('/');

/// Prompt IDs are response metadata, but they become the cursor and entity
/// identity used by every client after an append. Keep the ordinary write
/// response aligned with Core/Runtime before exposing it to a session UI.
bool _validPromptResponseID(String value) =>
    value.trim().isNotEmpty &&
    utf8.encode(value).length <= 128 &&
    !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

bool _validIdempotencyKey(String value) =>
    value.isNotEmpty &&
    value == value.trim() &&
    utf8.encode(value).length <= 256 &&
    !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

bool _isSafeBearerToken(String value) =>
    value.isNotEmpty &&
    value == value.trim() &&
    !value.contains(RegExp(r'[\r\n]'));

/// Dart's JSON decoder keeps the last value when an object repeats a key.
/// Forge responses are owner-scoped contracts, so accepting that ambiguity
/// could let a later field silently replace a validated earlier field. Scan
/// the raw response first and reject duplicate keys at every object depth.
void _rejectDuplicateForgeJsonKeys(String body) {
  _ForgeJsonDuplicateKeyScanner(body).scan();
}

bool _isForgeJsonWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';

/// A small JSON grammar scanner used only to detect repeated object keys.
///
/// A character search is insufficient here: braces and quoted colons are
/// ordinary string data, and escaped key spellings such as `"a"` and
/// `"\\u0061"` identify the same JSON member. The scanner follows the JSON
/// structure and decodes only member names; the normal decoder still owns the
/// final response shape/type validation.
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
    _index++; // {
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
    _index++; // [
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
        final escaped = _body[_index++];
        if (escaped == 'u') {
          if (_index + 4 > _body.length) {
            throw const FormatException('Forge returned invalid JSON.');
          }
          for (var digit = 0; digit < 4; digit++) {
            if (!_isHexDigit(_body[_index++])) {
              throw const FormatException('Forge returned invalid JSON.');
            }
          }
        } else if (!'"\\/bfnrt'.contains(escaped)) {
          throw const FormatException('Forge returned invalid JSON.');
        }
        continue;
      }
      if (character.codeUnitAt(0) < 0x20) {
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
    if (_consume('-')) {
      if (_index >= _body.length) {
        throw const FormatException('Forge returned invalid JSON.');
      }
    }
    if (_consume('0')) {
      if (_index < _body.length && _isDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
    } else {
      if (_index >= _body.length || !_isNonZeroDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
      while (_index < _body.length && _isDigit(_body[_index])) {
        _index++;
      }
    }
    if (_consume('.')) {
      if (_index >= _body.length || !_isDigit(_body[_index])) {
        throw const FormatException('Forge returned invalid JSON.');
      }
      while (_index < _body.length && _isDigit(_body[_index])) {
        _index++;
      }
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
      while (_index < _body.length && _isDigit(_body[_index])) {
        _index++;
      }
    }
    if (_index == start) {
      throw const FormatException('Forge returned invalid JSON.');
    }
  }

  void _skipWhitespace() {
    while (_index < _body.length && _isForgeJsonWhitespace(_body[_index])) {
      _index++;
    }
  }

  void _expect(String character) {
    if (!_consume(character)) {
      throw const FormatException('Forge returned invalid JSON.');
    }
  }

  bool _consume(String character) {
    if (_index < _body.length && _body[_index] == character) {
      _index++;
      return true;
    }
    return false;
  }

  static bool _isDigit(String character) =>
      character.codeUnitAt(0) >= 0x30 && character.codeUnitAt(0) <= 0x39;

  static bool _isNonZeroDigit(String character) =>
      character.codeUnitAt(0) >= 0x31 && character.codeUnitAt(0) <= 0x39;

  static bool _isHexDigit(String character) {
    final code = character.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x46) ||
        (code >= 0x61 && code <= 0x66);
  }
}
