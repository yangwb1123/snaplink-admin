part of 'forge_prompt_append_receipt.dart';

Map<String, dynamic> _promptAppendObject(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

void _promptAppendExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String label,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw FormatException('$label contains unknown or missing fields.');
  }
}

String _promptAppendText(Object? value, String label) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('$label is invalid.');
  }
  return value;
}

String _promptAppendIdentifier(Object? value, String label) {
  final text = _promptAppendText(value, label);
  if (text.length > 128 ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+/-]*$').hasMatch(text)) {
    throw FormatException('$label identifier is invalid.');
  }
  return text;
}

String _promptAppendRole(Object? value) {
  final role = _promptAppendText(value, 'role');
  if (role != 'user') throw const FormatException('Prompt role is invalid.');
  return role;
}

String _promptAppendDigest(Object? value, String label) {
  final digest = _promptAppendText(value, label);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
    throw FormatException('$label digest is invalid.');
  }
  return digest;
}

int _promptAppendPositiveInt(Object? value, String label) {
  final number = _promptAppendUint(value, label);
  if (number <= 0) throw FormatException('$label must be positive.');
  return number;
}

int _promptAppendUint(Object? value, String label) {
  if (value is! int ||
      value < 0 ||
      value > forgePromptAppendReceiptMaxSafeInteger) {
    throw FormatException('$label is invalid.');
  }
  return value;
}

bool _promptAppendBool(Object? value, String label) {
  if (value is! bool) throw FormatException('$label is invalid.');
  return value;
}
