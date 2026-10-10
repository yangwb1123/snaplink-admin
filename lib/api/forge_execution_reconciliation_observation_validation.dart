part of 'forge_execution_reconciliation_observation.dart';

Map<String, dynamic> _reconciliationObject(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException(
      'Forge execution reconciliation $label must be an object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _reconciliationExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge execution reconciliation fields.',
    );
  }
}

bool _reconciliationBool(Object? value) {
  if (value is! bool) {
    throw const FormatException(
      'Invalid Forge execution reconciliation boolean.',
    );
  }
  return value;
}

int _reconciliationSafeInteger(Object? value) {
  if (value is int &&
      value >= 0 &&
      value <= forgeExecutionReconciliationMaxSafeInteger) {
    return value;
  }
  throw const FormatException(
    'Forge execution reconciliation integer is outside the safe range.',
  );
}

int _reconciliationPositiveSafeInteger(Object? value) {
  final integer = _reconciliationSafeInteger(value);
  if (integer < 1) {
    throw const FormatException(
      'Forge execution reconciliation integer must be positive.',
    );
  }
  return integer;
}

int _reconciliationVersion(Object? value) {
  if (value is! int || value != 1) {
    throw const FormatException(
      'Unsupported Forge execution reconciliation version.',
    );
  }
  return value;
}

String _reconciliationSchema(Object? value) {
  if (value != forgeExecutionReconciliationObservationSchema) {
    throw const FormatException(
      'Invalid Forge execution reconciliation schema.',
    );
  }
  return forgeExecutionReconciliationObservationSchema;
}

String _reconciliationMode(Object? value) {
  if (value != forgeExecutionReconciliationObservationEvaluationMode) {
    throw const FormatException(
      'Invalid Forge execution reconciliation evaluation mode.',
    );
  }
  return forgeExecutionReconciliationObservationEvaluationMode;
}

String _reconciliationIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      utf8.encode(value).length > 85 ||
      !_reconciliationWellFormedUnicode(value) ||
      RegExp(r'\s').hasMatch(value) ||
      value.runes.any(
        (rune) =>
            rune <= 0x20 ||
            (rune >= 0x7f && rune <= 0x9f) ||
            rune == 0x3a ||
            rune == 0x2f ||
            rune == 0x5c,
      )) {
    throw const FormatException(
      'Invalid Forge execution reconciliation identifier.',
    );
  }
  return value;
}

String _reconciliationRunStatus(Object? value) => _reconciliationOneOf(value, {
  'nonterminal',
  'completed',
  'cancelled',
  'limit_exceeded',
  'failed',
}, 'Run status');

String _reconciliationAttemptState(Object? value) =>
    _reconciliationOneOf(value, {
      'requested',
      'accepted',
      'starting',
      'running',
      'interrupted',
      'completed',
      'failed',
      'uncertain',
    }, 'Attempt state');

String _reconciliationTerminalDisposition(Object? value) =>
    _reconciliationOneOf(value, {
      'none',
      'completed',
      'failed',
      'uncertain',
    }, 'terminal disposition');

String _reconciliationNextObservation(Object? value) =>
    _reconciliationOneOf(value, {
      'await_terminal',
      'lease_expired_without_terminal',
      'attempt_not_dispatchable',
      'attempt_terminal_without_receipt',
      'run_terminal_without_receipt',
      'terminal_completed',
      'terminal_failed',
      'terminal_uncertain',
      'terminal_state_conflict',
    }, 'next observation');

String _reconciliationOneOf(Object? value, Set<String> allowed, String label) {
  if (value is! String || !allowed.contains(value)) {
    throw FormatException('Invalid Forge execution reconciliation $label.');
  }
  return value;
}

bool _sameProof(ForgeRunnerLeaseProof left, ForgeRunnerLeaseProof right) =>
    left.attemptID == right.attemptID &&
    left.targetID == right.targetID &&
    left.epoch == right.epoch &&
    left.fencingToken == right.fencingToken;

bool _terminalStateMatchesAttempt(String disposition, String state) =>
    (disposition == 'completed' && state == 'completed') ||
    (disposition == 'failed' && state == 'failed') ||
    (disposition == 'uncertain' && state == 'uncertain');

bool _dispatchableAttemptState(String value) =>
    value == 'accepted' || value == 'starting' || value == 'running';

String _classify(
  String runStatus,
  String attemptState,
  bool leaseActive,
  bool terminalObserved,
  String terminalDisposition,
  bool terminalStateAligned,
) {
  if (terminalObserved) {
    if (!terminalStateAligned) return 'terminal_state_conflict';
    switch (terminalDisposition) {
      case 'completed':
        return 'terminal_completed';
      case 'failed':
        return 'terminal_failed';
      default:
        return 'terminal_uncertain';
    }
  }
  if (runStatus != 'nonterminal') return 'run_terminal_without_receipt';
  if (attemptState == 'completed' ||
      attemptState == 'failed' ||
      attemptState == 'uncertain') {
    return 'attempt_terminal_without_receipt';
  }
  if (!_dispatchableAttemptState(attemptState)) {
    return 'attempt_not_dispatchable';
  }
  if (!leaseActive) return 'lease_expired_without_terminal';
  return 'await_terminal';
}

bool _requiresReconciliation(String value) => const {
  'lease_expired_without_terminal',
  'attempt_not_dispatchable',
  'attempt_terminal_without_receipt',
  'run_terminal_without_receipt',
  'terminal_uncertain',
  'terminal_state_conflict',
}.contains(value);

bool _reconciliationWellFormedUnicode(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= (0xdb00 + 0xff)) {
      if (index + 1 >= value.length) return false;
      final next = value.codeUnitAt(++index);
      if (next < 0xdc00 || next > 0xdfff) return false;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}
