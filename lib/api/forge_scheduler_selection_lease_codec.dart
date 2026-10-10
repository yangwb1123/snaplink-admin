part of 'forge_scheduler_selection_lease.dart';

Map<String, dynamic> _leaseObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid Forge scheduler lease object.');
  }
  return Map<String, dynamic>.from(value);
}

void _leaseExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge scheduler lease fields.');
  }
}

bool _leaseBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge scheduler lease boolean.');
  }
  return value;
}

int _leasePositiveInt(Object? value) {
  final parsed = _leaseBoundedInt(value, 9007199254740991);
  if (parsed <= 0) {
    throw const FormatException('Invalid Forge scheduler lease integer.');
  }
  return parsed;
}

int _leaseBoundedInt(Object? value, int maximum) {
  if (value is! int || value < 0 || value > maximum) {
    throw const FormatException('Invalid Forge scheduler lease integer.');
  }
  return value;
}

String _leaseIdentifier(Object? value, {int maxLength = 128}) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maxLength ||
      value.trim() != value) {
    throw const FormatException('Invalid Forge scheduler lease identifier.');
  }
  for (var index = 0; index < value.length; index++) {
    final code = value.codeUnitAt(index);
    final valid =
        code >= 48 && code <= 57 ||
        code >= 65 && code <= 90 ||
        code >= 97 && code <= 122 ||
        index > 0 && '.:_+/-'.codeUnits.contains(code);
    if (!valid) {
      throw const FormatException('Invalid Forge scheduler lease identifier.');
    }
  }
  return value;
}

class _LeaseDuplicateScanner {
  final String source;
  var index = 0;
  _LeaseDuplicateScanner(this.source);

  void scan() {
    _value();
    _space();
    if (index != source.length) {
      throw const FormatException('Trailing Forge scheduler lease JSON.');
    }
  }

  void _value() {
    _space();
    if (index >= source.length) {
      throw const FormatException('Invalid Forge scheduler lease JSON.');
    }
    switch (source.codeUnitAt(index)) {
      case 123:
        _object();
        return;
      case 91:
        _array();
        return;
      case 34:
        _string();
        return;
      default:
        _primitive();
        return;
    }
  }

  void _object() {
    index++;
    _space();
    final keys = <String>{};
    if (_take(125)) return;
    while (true) {
      _space();
      final start = index;
      _string();
      final key = jsonDecode(source.substring(start, index)) as String;
      if (!keys.add(key)) {
        throw const FormatException('Duplicate Forge scheduler lease key.');
      }
      _space();
      if (!_take(58)) {
        throw const FormatException('Invalid Forge scheduler lease object.');
      }
      _value();
      _space();
      if (_take(125)) return;
      if (!_take(44)) {
        throw const FormatException('Invalid Forge scheduler lease object.');
      }
    }
  }

  void _array() {
    index++;
    _space();
    if (_take(93)) return;
    while (true) {
      _value();
      _space();
      if (_take(93)) return;
      if (!_take(44)) {
        throw const FormatException('Invalid Forge scheduler lease array.');
      }
    }
  }

  void _string() {
    final start = index;
    if (!_take(34)) {
      throw const FormatException('Invalid Forge scheduler lease string.');
    }
    while (index < source.length) {
      final code = source.codeUnitAt(index++);
      if (code == 92) {
        if (index >= source.length) {
          throw const FormatException('Invalid Forge scheduler lease escape.');
        }
        index++;
      } else if (code == 34) {
        return;
      } else if (code < 32) {
        throw const FormatException('Invalid Forge scheduler lease string.');
      }
    }
    index = start;
    throw const FormatException('Unterminated Forge scheduler lease string.');
  }

  void _primitive() {
    final start = index;
    while (index < source.length && !' \t\r\n,]}'.contains(source[index])) {
      index++;
    }
    if (start == index) {
      throw const FormatException('Invalid Forge scheduler lease value.');
    }
  }

  void _space() {
    while (index < source.length && ' \t\r\n'.contains(source[index])) {
      index++;
    }
  }

  bool _take(int code) {
    if (index < source.length && source.codeUnitAt(index) == code) {
      index++;
      return true;
    }
    return false;
  }
}
