part of 'forge_runner_transport_admission.dart';

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected, String label) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw FormatException('$label contains unknown or missing fields.');
  }
}

String _text(Object? value, String label) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('$label is invalid.');
  }
  return value;
}

String _identifier(Object? value, {int maxLength = 128}) {
  final text = _text(value, 'identifier');
  if (text.length > maxLength ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+/-]*$').hasMatch(text)) {
    throw const FormatException('Identifier is invalid.');
  }
  return text;
}

String _digest(Object? value) {
  final text = _text(value, 'digest');
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw const FormatException('Digest is invalid.');
  }
  return text;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int ||
      value <= 0 ||
      value > ForgeRunnerTransportAdmission._maxSafeInteger) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

int _boundedInt(Map<String, dynamic> json, String key, int max) {
  final value = json[key];
  if (value is! int || value <= 0 || value > max) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is invalid.');
  return value;
}

String _state(Object? value) {
  final state = _text(value, 'attempt_state');
  if (!{
    'requested',
    'accepted',
    'starting',
    'running',
    'interrupted',
    'completed',
    'failed',
    'uncertain',
  }.contains(state)) {
    throw const FormatException('Attempt state is invalid.');
  }
  return state;
}

bool _dispatchable(String state) =>
    {'accepted', 'starting', 'running'}.contains(state);

List<String> _reasons(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Rejection reasons are invalid.');
  }
  final reasons = value.cast<String>().toList(growable: false);
  final sorted = [...reasons]..sort();
  if (reasons.toSet().length != reasons.length ||
      reasons.join('|') != sorted.join('|')) {
    throw const FormatException('Rejection reasons are not sorted.');
  }
  return List.unmodifiable(reasons);
}
