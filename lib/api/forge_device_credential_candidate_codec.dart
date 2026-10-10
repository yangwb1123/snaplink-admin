part of 'forge_device_credential_candidate.dart';

Map<String, dynamic> _credentialCandidateObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Forge credential candidate $label must be an object.',
    );
  }
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw FormatException(
      'Forge credential candidate $label has invalid keys.',
    );
  }
}

void _credentialCandidateExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge credential candidate fields.',
    );
  }
}

String _credentialCandidateIdentifier(Object? value, String label) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_credentialCandidateASCIIIdentifier(value)) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

bool _credentialCandidateASCIIIdentifier(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) || const [0x2e, 0x5f, 0x3a, 0x2d].contains(code);
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

String _credentialCandidateOneOf(
  Object? value,
  Set<String> allowed,
  String label,
) {
  if (value is! String || !allowed.contains(value)) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

String _credentialCandidateOptionalOneOf(
  Object? value,
  Set<String> allowed,
  String label,
) {
  if (value is! String || (value.isNotEmpty && !allowed.contains(value))) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

String _credentialCandidateOptionalIdentifier(Object? value, String label) {
  if (value is! String) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value.isEmpty ? value : _credentialCandidateIdentifier(value, label);
}

String _credentialCandidateDigest(Object? value, String label) {
  if (value is! String ||
      value.length != 64 ||
      value.runes.any(
        (rune) =>
            !(rune >= 0x30 && rune <= 0x39 || rune >= 0x61 && rune <= 0x66),
      )) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

String _credentialCandidateOptionalDigest(Object? value, String label) {
  if (value is! String) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value.isEmpty ? value : _credentialCandidateDigest(value, label);
}

int _credentialCandidateSafeInteger(Object? value, String label) {
  if (value is! int ||
      value < 0 ||
      value > forgeDeviceCredentialCandidateMaxSafeInteger) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

int _credentialCandidatePositiveSafeInteger(Object? value, String label) {
  final number = _credentialCandidateSafeInteger(value, label);
  if (number == 0) {
    throw FormatException(
      'Forge credential candidate $label must be positive.',
    );
  }
  return number;
}

bool _credentialCandidateBool(Object? value, String label) {
  if (value is! bool) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

void _credentialCandidateRejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character == '\\') {
        escaped = true;
      } else if (character == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Forge credential candidate contains duplicate JSON fields.',
            );
          }
        }
      }
      continue;
    }
    if (character == '"') {
      inString = true;
      stringStart = index;
    } else if (character == '{') {
      objects.add(<String>{});
    } else if (character == '}') {
      if (objects.isEmpty) {
        throw const FormatException('Invalid Forge credential candidate JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge credential candidate JSON.');
  }
}
