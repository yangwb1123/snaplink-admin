import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

/// A typed, display-only observation of a future Runner dispatch plan.
///
/// The value is intentionally detached from HTTP, inventory authority, lease
/// issuance, target selection, and execution. It is suitable for an explicit
/// fixture or candidate reader while the live dispatch boundary remains
/// gated.
class ForgeRunnerDispatchPlanPreview {
  static const schemaVersion = 'forge.runner-dispatch-plan-preview/v1';
  static const expectedEvaluationMode = 'pure_dispatch_plan_preview_only';
  static const _maxSafeInteger = 9007199254740991;
  static const _maxCandidates = 128;
  static const _fields = {
    'schema_version',
    'evaluation_mode',
    'owner_declaration',
    'conversation_id',
    'run_id',
    'attempt_id',
    'attempt_state',
    'attempt_state_admissible',
    'command_id',
    'command_sha256',
    'intent_target_id',
    'lease_epoch',
    'lease_active',
    'evaluated_at_ms',
    'candidate_count',
    'declarative_ready_count',
    'candidates',
    'selected_target_id',
    'preview_only',
    'reservation_created',
    'execution_authorized',
    'dispatch_performed',
    'authority',
  };
  static const _authorityFields = {
    'device_identity_verified',
    'attempt_persisted',
    'reservation_created',
    'execution_authorized',
    'dispatch_performed',
    'audit_published',
  };

  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String attemptState;
  final bool attemptStateAdmissible;
  final String commandID;
  final String commandSHA256;
  final String intentTargetID;
  final int leaseEpoch;
  final bool leaseActive;
  final int evaluatedAtMS;
  final int candidateCount;
  final int declarativeReadyCount;
  final List<ForgeRunnerDispatchPlanCandidate> candidates;
  final String? selectedTargetID;
  final bool previewOnly;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final Map<String, bool> authority;

  const ForgeRunnerDispatchPlanPreview({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.attemptState,
    required this.attemptStateAdmissible,
    required this.commandID,
    required this.commandSHA256,
    required this.intentTargetID,
    required this.leaseEpoch,
    required this.leaseActive,
    required this.evaluatedAtMS,
    required this.candidateCount,
    required this.declarativeReadyCount,
    required this.candidates,
    required this.selectedTargetID,
    required this.previewOnly,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.authority,
  });

  String get evaluationMode => expectedEvaluationMode;

  factory ForgeRunnerDispatchPlanPreview.fromJsonText(String source) {
    _rejectDuplicateObjectKeys(source);
    final value = jsonDecode(source);
    return ForgeRunnerDispatchPlanPreview.fromJson(value);
  }

  factory ForgeRunnerDispatchPlanPreview.fromJson(Object? value) {
    final json = _object(value, 'observation');
    _exactKeys(json, _fields, 'observation');
    if (json['schema_version'] != schemaVersion ||
        json['evaluation_mode'] != expectedEvaluationMode ||
        json['selected_target_id'] != null ||
        json['preview_only'] != true ||
        json['reservation_created'] != false ||
        json['execution_authorized'] != false ||
        json['dispatch_performed'] != false) {
      throw const FormatException(
        'Invalid Forge Runner dispatch-plan preview envelope.',
      );
    }

    final owner = ForgeDeviceOwner.fromJson(json['owner_declaration']);
    final authority = _authority(json['authority']);
    final attemptState = _attemptState(json['attempt_state']);
    final attemptStateAdmissible = _bool(json, 'attempt_state_admissible');
    if (attemptStateAdmissible != _dispatchableAttemptState(attemptState)) {
      throw const FormatException(
        'Invalid Runner dispatch-plan Attempt admissibility.',
      );
    }

    final candidateCount = _boundedInt(json, 'candidate_count', _maxCandidates);
    final declarativeReadyCount = _boundedInt(
      json,
      'declarative_ready_count',
      candidateCount,
    );
    final rawCandidates = json['candidates'];
    if (rawCandidates is! List || rawCandidates.length != candidateCount) {
      throw const FormatException(
        'Runner dispatch-plan candidate count does not match.',
      );
    }
    final candidates = rawCandidates
        .map(ForgeRunnerDispatchPlanCandidate.fromJson)
        .toList(growable: false);
    final intentTargetID = _identifier(json['intent_target_id']);
    final leaseActive = _bool(json, 'lease_active');
    final readyCount = _validateCandidates(
      candidates,
      intentTargetID: intentTargetID,
      leaseActive: leaseActive,
      attemptStateAdmissible: attemptStateAdmissible,
    );
    if (readyCount != declarativeReadyCount) {
      throw const FormatException(
        'Runner dispatch-plan ready count does not match candidates.',
      );
    }

    return ForgeRunnerDispatchPlanPreview(
      owner: owner,
      conversationID: _identifier(json['conversation_id']),
      runID: _identifier(json['run_id']),
      attemptID: _identifier(json['attempt_id']),
      attemptState: attemptState,
      attemptStateAdmissible: attemptStateAdmissible,
      commandID: _identifier(json['command_id']),
      commandSHA256: _digest(json['command_sha256']),
      intentTargetID: intentTargetID,
      leaseEpoch: _positiveInt(json, 'lease_epoch'),
      leaseActive: leaseActive,
      evaluatedAtMS: _positiveInt(json, 'evaluated_at_ms'),
      candidateCount: candidateCount,
      declarativeReadyCount: declarativeReadyCount,
      candidates: List.unmodifiable(candidates),
      selectedTargetID: null,
      previewOnly: true,
      reservationCreated: false,
      executionAuthorized: false,
      dispatchPerformed: false,
      authority: authority,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': expectedEvaluationMode,
    'owner_declaration': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'attempt_state': attemptState,
    'attempt_state_admissible': attemptStateAdmissible,
    'command_id': commandID,
    'command_sha256': commandSHA256,
    'intent_target_id': intentTargetID,
    'lease_epoch': leaseEpoch,
    'lease_active': leaseActive,
    'evaluated_at_ms': evaluatedAtMS,
    'candidate_count': candidateCount,
    'declarative_ready_count': declarativeReadyCount,
    'candidates': candidates.map((candidate) => candidate.toJson()).toList(),
    'selected_target_id': selectedTargetID,
    'preview_only': previewOnly,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'authority': authority,
  };

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  bool get isDisplayOnly =>
      previewOnly &&
      selectedTargetID == null &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      authority.values.every((value) => !value);

  static Map<String, bool> _authority(Object? value) {
    final json = _object(value, 'authority');
    _exactKeys(json, _authorityFields, 'authority');
    final result = <String, bool>{};
    for (final key in _authorityFields) {
      final value = json[key];
      if (value is! bool || value) {
        throw FormatException('authority.$key must be false');
      }
      result[key] = false;
    }
    return Map.unmodifiable(result);
  }

  static int _validateCandidates(
    List<ForgeRunnerDispatchPlanCandidate> candidates, {
    required String intentTargetID,
    required bool leaseActive,
    required bool attemptStateAdmissible,
  }) {
    var readyCount = 0;
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      if (index > 0 &&
          candidates[index - 1].targetID.compareTo(candidate.targetID) >= 0) {
        throw const FormatException(
          'Runner dispatch-plan candidates must be sorted uniquely.',
        );
      }
      if (!candidate.attributesUnverified ||
          candidate.leaseTargetMatch !=
              (candidate.targetID == intentTargetID) ||
          candidate.leaseActive != leaseActive ||
          candidate.attemptStateAdmissible != attemptStateAdmissible ||
          candidate.declarativeReady !=
              (candidate.matchesRequirements &&
                  candidate.leaseTargetMatch &&
                  candidate.leaseActive &&
                  candidate.attemptStateAdmissible) ||
          (candidate.declarativeReady && candidate.reasons.isNotEmpty)) {
        throw const FormatException('Invalid Runner dispatch-plan candidate.');
      }
      if (candidate.declarativeReady) readyCount++;
    }
    return readyCount;
  }

  static Map<String, dynamic> _object(Object? value, String label) {
    if (value is! Map) throw FormatException('$label must be an object');
    return Map<String, dynamic>.from(value);
  }

  static void _exactKeys(
    Map<String, dynamic> json,
    Set<String> expected,
    String label,
  ) {
    if (json.length != expected.length ||
        json.keys.any((key) => !expected.contains(key))) {
      throw FormatException('Unknown or missing $label field');
    }
  }

  static bool _bool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('$key must be bool');
    return value;
  }

  static int _positiveInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value <= 0 || value > _maxSafeInteger) {
      throw FormatException('$key is out of range');
    }
    return value;
  }

  static int _boundedInt(Map<String, dynamic> json, String key, int maximum) {
    final value = json[key];
    if (value is! int || value < 0 || value > maximum) {
      throw FormatException('$key is out of range');
    }
    return value;
  }

  static String _identifier(Object? value) {
    if (value is! String ||
        value.isEmpty ||
        value.length > 128 ||
        !_identifierCodeUnits(value)) {
      throw const FormatException('Invalid Runner dispatch-plan identifier.');
    }
    return value;
  }

  static bool _identifierCodeUnits(String value) {
    bool alphaNumeric(int code) =>
        code >= 0x30 && code <= 0x39 ||
        code >= 0x41 && code <= 0x5a ||
        code >= 0x61 && code <= 0x7a;
    bool allowedRest(int code) =>
        alphaNumeric(code) ||
        const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code);
    final codes = value.codeUnits;
    return alphaNumeric(codes.first) && codes.skip(1).every(allowedRest);
  }

  static String _digest(Object? value) {
    if (value is! String ||
        value.length != 64 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw const FormatException('Invalid Runner command digest.');
    }
    return value;
  }

  static String _attemptState(Object? value) {
    const allowed = {
      'requested',
      'accepted',
      'starting',
      'running',
      'interrupted',
      'completed',
      'failed',
      'uncertain',
    };
    if (value is! String || !allowed.contains(value)) {
      throw const FormatException(
        'Invalid Runner dispatch-plan Attempt state.',
      );
    }
    return value;
  }

  static bool _dispatchableAttemptState(String state) =>
      {'accepted', 'starting', 'running'}.contains(state);
}

class ForgeRunnerDispatchPlanCandidate {
  final String targetID;
  final bool attributesUnverified;
  final bool matchesRequirements;
  final bool leaseTargetMatch;
  final bool leaseActive;
  final bool attemptStateAdmissible;
  final bool declarativeReady;
  final List<String> reasons;

  const ForgeRunnerDispatchPlanCandidate({
    required this.targetID,
    required this.attributesUnverified,
    required this.matchesRequirements,
    required this.leaseTargetMatch,
    required this.leaseActive,
    required this.attemptStateAdmissible,
    required this.declarativeReady,
    required this.reasons,
  });

  factory ForgeRunnerDispatchPlanCandidate.fromJson(Object? value) {
    final json = _candidateObject(value);
    _candidateExactKeys(json);
    final reasons = _sortedUniqueStrings(json['reasons']);
    return ForgeRunnerDispatchPlanCandidate(
      targetID: _candidateIdentifier(json['target_id']),
      attributesUnverified: _candidateBool(json, 'attributes_unverified'),
      matchesRequirements: _candidateBool(json, 'matches_requirements'),
      leaseTargetMatch: _candidateBool(json, 'lease_target_match'),
      leaseActive: _candidateBool(json, 'lease_active'),
      attemptStateAdmissible: _candidateBool(json, 'attempt_state_admissible'),
      declarativeReady: _candidateBool(json, 'declarative_ready'),
      reasons: reasons,
    );
  }

  Map<String, dynamic> toJson() => {
    'target_id': targetID,
    'attributes_unverified': attributesUnverified,
    'matches_requirements': matchesRequirements,
    'lease_target_match': leaseTargetMatch,
    'lease_active': leaseActive,
    'attempt_state_admissible': attemptStateAdmissible,
    'declarative_ready': declarativeReady,
    'reasons': reasons,
  };

  static Map<String, dynamic> _candidateObject(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Runner dispatch-plan candidate must be an object.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  static void _candidateExactKeys(Map<String, dynamic> json) {
    const expected = {
      'target_id',
      'attributes_unverified',
      'matches_requirements',
      'lease_target_match',
      'lease_active',
      'attempt_state_admissible',
      'declarative_ready',
      'reasons',
    };
    if (json.length != expected.length ||
        json.keys.any((key) => !expected.contains(key))) {
      throw const FormatException(
        'Unknown or missing Runner dispatch-plan candidate field.',
      );
    }
  }

  static bool _candidateBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('$key must be bool');
    return value;
  }

  static String _candidateIdentifier(Object? value) {
    if (value is! String ||
        value.isEmpty ||
        value.length > 128 ||
        !_candidateIdentifierCodeUnits(value)) {
      throw const FormatException(
        'Invalid Runner dispatch-plan candidate identifier.',
      );
    }
    return value;
  }

  static bool _candidateIdentifierCodeUnits(String value) {
    bool alphaNumeric(int code) =>
        code >= 0x30 && code <= 0x39 ||
        code >= 0x41 && code <= 0x5a ||
        code >= 0x61 && code <= 0x7a;
    bool allowedRest(int code) =>
        alphaNumeric(code) ||
        const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code);
    final codes = value.codeUnits;
    return alphaNumeric(codes.first) && codes.skip(1).every(allowedRest);
  }

  static List<String> _sortedUniqueStrings(Object? value) {
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException(
        'Runner dispatch-plan reasons must be strings.',
      );
    }
    final values = value.cast<String>().toList(growable: false);
    for (var index = 1; index < values.length; index++) {
      if (values[index - 1].compareTo(values[index]) >= 0) {
        throw const FormatException(
          'Runner dispatch-plan reasons must be sorted uniquely.',
        );
      }
    }
    return List.unmodifiable(values);
  }
}

// jsonDecode silently keeps the last value for duplicate object keys. Parse
// the object/array nesting before decoding so repeated candidate member names
// in separate array elements remain valid while a duplicate in one object is
// rejected.
void _rejectDuplicateObjectKeys(String source) {
  _DuplicateKeyScanner(source).scan();
}

class _DuplicateKeyScanner {
  final String source;
  var _index = 0;

  _DuplicateKeyScanner(this.source);

  void scan() {
    _parseValue();
    _skipWhitespace();
    if (_index != source.length) {
      throw const FormatException('trailing JSON value');
    }
  }

  void _parseValue() {
    _skipWhitespace();
    if (_index >= source.length) {
      throw const FormatException('missing JSON value');
    }
    switch (source[_index]) {
      case '{':
        _parseObject();
      case '[':
        _parseArray();
      case '"':
        _parseString();
      default:
        _parseScalar();
    }
  }

  void _parseObject() {
    _expect('{');
    _skipWhitespace();
    final keys = <String>{};
    if (_take('}')) return;
    while (true) {
      _skipWhitespace();
      final keyStart = _index;
      final keyEnd = _parseString();
      final key = jsonDecode(source.substring(keyStart, keyEnd)) as String;
      if (!keys.add(key)) {
        throw FormatException('duplicate object key: $key');
      }
      _skipWhitespace();
      _expect(':');
      _parseValue();
      _skipWhitespace();
      if (_take('}')) return;
      _expect(',');
    }
  }

  void _parseArray() {
    _expect('[');
    _skipWhitespace();
    if (_take(']')) return;
    while (true) {
      _parseValue();
      _skipWhitespace();
      if (_take(']')) return;
      _expect(',');
    }
  }

  int _parseString() {
    _expect('"');
    var escaped = false;
    while (_index < source.length) {
      final char = source[_index++];
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        return _index;
      }
    }
    throw const FormatException('unterminated JSON string');
  }

  void _parseScalar() {
    final start = _index;
    while (_index < source.length && !' \t\r\n,]}'.contains(source[_index])) {
      _index++;
    }
    if (start == _index) {
      throw const FormatException('invalid JSON scalar');
    }
  }

  void _skipWhitespace() {
    while (_index < source.length && ' \t\r\n'.contains(source[_index])) {
      _index++;
    }
  }

  bool _take(String expected) {
    if (_index < source.length && source[_index] == expected) {
      _index++;
      return true;
    }
    return false;
  }

  void _expect(String expected) {
    if (!_take(expected)) {
      throw FormatException('expected JSON $expected');
    }
  }
}
