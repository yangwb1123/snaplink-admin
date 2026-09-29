part of 'forge_runner_attempt_boundary.dart';

Map<String, dynamic> _attemptBoundaryObject(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

void _attemptBoundaryExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String label,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw FormatException('$label contains unknown or missing fields.');
  }
}

String _attemptBoundaryText(Object? value, String label) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('$label is invalid.');
  }
  return value;
}

String _attemptBoundaryIdentifier(Object? value) {
  final text = _attemptBoundaryText(value, 'identifier');
  if (text.length > 128 ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+/-]*$').hasMatch(text)) {
    throw const FormatException(
      'Runner Attempt boundary identifier is invalid.',
    );
  }
  return text;
}

int _attemptBoundaryPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int ||
      value <= 0 ||
      value > forgeRunnerAttemptBoundaryMaxSafeInteger) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

bool _attemptBoundaryBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is invalid.');
  return value;
}

String _attemptBoundaryState(Object? value) {
  final state = _attemptBoundaryText(value, 'Attempt state');
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

String _attemptBoundaryTransition(Object? value) {
  final transition = _attemptBoundaryText(value, 'Attempt transition');
  if (!{
    'accept',
    'begin_starting',
    'observe_running',
    'observe_interrupted',
    'observe_completed',
    'observe_failed',
    'observe_effect_outcome_uncertain',
  }.contains(transition)) {
    throw const FormatException('Attempt transition is invalid.');
  }
  return transition;
}

String _attemptBoundaryTransitionTarget(String transition) =>
    switch (transition) {
      'accept' => 'accepted',
      'begin_starting' => 'starting',
      'observe_running' => 'running',
      'observe_interrupted' => 'interrupted',
      'observe_completed' => 'completed',
      'observe_failed' => 'failed',
      'observe_effect_outcome_uncertain' => 'uncertain',
      _ => '',
    };

bool _attemptBoundaryValidTransition(String current, String next) =>
    switch (current) {
      'requested' => next == 'accepted',
      'accepted' => {
        'starting',
        'interrupted',
        'failed',
        'uncertain',
      }.contains(next),
      'starting' => {
        'running',
        'interrupted',
        'failed',
        'uncertain',
      }.contains(next),
      'running' => {
        'interrupted',
        'completed',
        'failed',
        'uncertain',
      }.contains(next),
      _ => false,
    };

bool _attemptBoundaryDispatchable(String current, String next) =>
    (current == 'accepted' && next == 'starting') ||
    (current == 'starting' && next == 'running');

bool _attemptBoundaryDispatchableState(String state) =>
    {'accepted', 'starting', 'running'}.contains(state);

List<String> _attemptBoundaryReasons(Object? value) {
  if (value is! List ||
      value.length > 3 ||
      value.any((item) => item is! String)) {
    throw const FormatException(
      'Attempt boundary rejection reasons are invalid.',
    );
  }
  return List<String>.from(value);
}

List<String> _attemptBoundaryRejectionReasons(
  bool executionReady,
  bool transitionValid,
  bool transitionDispatchable,
) {
  final reasons = <String>[];
  if (!executionReady) reasons.add('execution_boundary_not_ready');
  if (!transitionValid) {
    reasons.add('attempt_transition_invalid');
  } else if (!transitionDispatchable) {
    reasons.add('attempt_transition_not_dispatchable');
  }
  reasons.sort();
  return reasons;
}

bool _attemptBoundarySameStrings(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}
