part of 'forge_client_instance_resource_view.dart';

bool _sameOwner(ForgeDeviceOwner left, ForgeDeviceOwner right) =>
    left.issuer == right.issuer &&
    left.subject == right.subject &&
    left.tenantID == right.tenantID;

Map<String, dynamic> _resourceViewObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Forge client-instance/resource-view $label must be an object.',
    );
  }
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _resourceViewExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge client-instance/resource-view fields.',
    );
  }
}

String _resourceViewIdentifier(Object? value, String label) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_resourceViewASCIIIdentifier(value)) {
    throw FormatException(
      'Invalid Forge client-instance/resource-view $label.',
    );
  }
  return value;
}

bool _resourceViewASCIIIdentifier(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) || const [0x2e, 0x5f, 0x3a, 0x2d, 0x2b, 0x2f].contains(code);
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

String _resourceViewToken(Object? value, String label) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      value.codeUnits.any(
        (code) =>
            !(code >= 0x30 && code <= 0x39 ||
                code >= 0x41 && code <= 0x5a ||
                code >= 0x61 && code <= 0x7a ||
                const [0x2e, 0x5f, 0x3a, 0x2d, 0x2b, 0x2f].contains(code)),
      )) {
    throw FormatException(
      'Invalid Forge client-instance/resource-view $label.',
    );
  }
  return value;
}

String _resourceViewOneOf(Object? value, Set<String> allowed, String label) {
  if (value is! String || !allowed.contains(value)) {
    throw FormatException(
      'Invalid Forge client-instance/resource-view $label.',
    );
  }
  return value;
}

int _resourceViewPositiveSafeInteger(Object? value, String label) {
  if (value is! int ||
      value <= 0 ||
      value > forgeClientInstanceResourceViewMaxSafeInteger) {
    throw FormatException(
      'Invalid Forge client-instance/resource-view $label.',
    );
  }
  return value;
}

int _resourceViewNonNegativeSafeInteger(Object? value, String label) {
  if (value is! int ||
      value < 0 ||
      value > forgeClientInstanceResourceViewMaxSafeInteger) {
    throw FormatException(
      'Invalid Forge client-instance/resource-view $label.',
    );
  }
  return value;
}

void _resourceViewRejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Duplicate Forge client-instance/resource-view JSON key.',
            );
          }
        }
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      stringStart = index;
    } else if (char == '{') {
      objects.add(<String>{});
    } else if (char == '}') {
      if (objects.isEmpty) {
        throw const FormatException(
          'Invalid Forge client-instance/resource-view JSON.',
        );
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException(
      'Invalid Forge client-instance/resource-view JSON.',
    );
  }
}
