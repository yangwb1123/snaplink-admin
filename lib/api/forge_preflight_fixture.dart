import 'dart:convert';

typedef JsonObject = Map<String, dynamic>;

/// The read-only, local representation of the Forge preflight fixture.
///
/// This deliberately has no transport or execution dependency. It is useful
/// for rendering a known contract fixture while the production dispatch path
/// is still being developed.
class ForgePreflightFixture {
  static const schemaVersion = 'forge.run-attempt-lease-dispatch-preflight/v1';
  static const expectedEvaluationMode =
      'pure_run_attempt_lease_dispatch_preflight';
  static const _maxSafeInteger = 9007199254740991;
  static const _fields = {
    'schema_version',
    'evaluation_mode',
    'owner',
    'conversation_id',
    'run_id',
    'run_status',
    'run_state_admissible',
    'attempt_id',
    'attempt_state',
    'attempt_state_admissible',
    'command_id',
    'intent_target_id',
    'lease_epoch',
    'lease_active',
    'evaluated_at_ms',
    'candidate_count',
    'declarative_ready_count',
    'declarative_preflight_ready',
    'rejection_reasons',
    'selected_target_id',
    'preview_only',
    'authority',
  };
  static const _authorityFields = {
    'identity_verified',
    'run_authoritative',
    'attempt_persisted',
    'lease_issued',
    'reservation_created',
    'execution_authorized',
    'dispatch_performed',
    'audit_published',
  };

  final String evaluationMode;
  final String issuer;
  final String subject;
  final String tenantId;
  final String conversationId;
  final String runId;
  final String runStatus;
  final bool runStateAdmissible;
  final String attemptId;
  final String attemptState;
  final bool attemptStateAdmissible;
  final String commandId;
  final String intentTargetId;
  final int leaseEpoch;
  final bool leaseActive;
  final int evaluatedAtMs;
  final int candidateCount;
  final int declarativeReadyCount;
  final bool declarativePreflightReady;
  final List<String> rejectionReasons;
  final String? selectedTargetId;
  final bool previewOnly;
  final Map<String, bool> authority;

  const ForgePreflightFixture({
    required this.evaluationMode,
    required this.issuer,
    required this.subject,
    required this.tenantId,
    required this.conversationId,
    required this.runId,
    required this.runStatus,
    required this.runStateAdmissible,
    required this.attemptId,
    required this.attemptState,
    required this.attemptStateAdmissible,
    required this.commandId,
    required this.intentTargetId,
    required this.leaseEpoch,
    required this.leaseActive,
    required this.evaluatedAtMs,
    required this.candidateCount,
    required this.declarativeReadyCount,
    required this.declarativePreflightReady,
    required this.rejectionReasons,
    required this.selectedTargetId,
    required this.previewOnly,
    required this.authority,
  });

  factory ForgePreflightFixture.fromJsonText(String source) {
    _rejectDuplicateObjectKeys(source);
    final value = jsonDecode(source);
    if (value is! Map) throw const FormatException('fixture must be an object');
    return ForgePreflightFixture.fromJson(Map<String, dynamic>.from(value));
  }

  factory ForgePreflightFixture.fromJson(JsonObject json) {
    _exactKeys(json, _fields, 'fixture');
    final owner = _object(json, 'owner');
    _exactKeys(owner, {'issuer', 'subject', 'tenant_id'}, 'owner');
    final authority = _object(json, 'authority');
    _exactKeys(authority, _authorityFields, 'authority');
    final values = <String, bool>{};
    for (final key in _authorityFields) {
      final value = authority[key];
      if (value is! bool) throw FormatException('authority.$key must be bool');
      if (value) throw FormatException('authority.$key must be false');
      values[key] = value;
    }
    if (json['schema_version'] != schemaVersion ||
        json['evaluation_mode'] != expectedEvaluationMode) {
      throw const FormatException('unsupported schema_version');
    }
    if (json['selected_target_id'] != null) {
      throw const FormatException('selected_target_id must be null');
    }
    if (json['preview_only'] != true) {
      throw const FormatException('fixture must be preview_only');
    }
    final runStatus = _text(json, 'run_status');
    final runStateAdmissible = _bool(json, 'run_state_admissible');
    if (!{
          'nonterminal',
          'completed',
          'cancelled',
          'limit_exceeded',
          'failed',
        }.contains(runStatus) ||
        runStateAdmissible != (runStatus == 'nonterminal')) {
      throw const FormatException('invalid Run state admissibility');
    }
    final attemptState = _text(json, 'attempt_state');
    final attemptStateAdmissible = _bool(json, 'attempt_state_admissible');
    if (!{
          'requested',
          'accepted',
          'starting',
          'running',
          'interrupted',
          'completed',
          'failed',
          'uncertain',
        }.contains(attemptState) ||
        attemptStateAdmissible !=
            {'accepted', 'starting', 'running'}.contains(attemptState)) {
      throw const FormatException('invalid Attempt state admissibility');
    }
    final leaseEpoch = _positiveInt(json, 'lease_epoch');
    if (leaseEpoch > _maxSafeInteger) {
      throw const FormatException('lease_epoch is out of range');
    }
    final evaluatedAtMs = _positiveInt(json, 'evaluated_at_ms');
    if (evaluatedAtMs > _maxSafeInteger) {
      throw const FormatException('evaluated_at_ms is out of range');
    }
    final candidateCount = _boundedInt(json, 'candidate_count', 128);
    final declarativeReadyCount = _boundedInt(
      json,
      'declarative_ready_count',
      candidateCount,
    );
    final leaseActive = _bool(json, 'lease_active');
    final declarativePreflightReady = _bool(
      json,
      'declarative_preflight_ready',
    );
    final rejectionReasons = _stringList(json, 'rejection_reasons');
    final expectedReasons = <String>[
      if (!runStateAdmissible) 'run_state_not_dispatchable',
      if (!attemptStateAdmissible) 'attempt_state_not_dispatchable',
      if (!leaseActive) 'lease_inactive_at_evaluated_time',
      if (declarativeReadyCount == 0) 'no_declarative_ready_candidate',
    ]..sort();
    if (!_sameStrings(rejectionReasons, expectedReasons) ||
        declarativePreflightReady !=
            (runStateAdmissible &&
                attemptStateAdmissible &&
                leaseActive &&
                declarativeReadyCount > 0)) {
      throw const FormatException('invalid preflight readiness');
    }
    return ForgePreflightFixture(
      evaluationMode: expectedEvaluationMode,
      issuer: _text(owner, 'issuer'),
      subject: _text(owner, 'subject'),
      tenantId: _text(owner, 'tenant_id'),
      conversationId: _text(json, 'conversation_id'),
      runId: _text(json, 'run_id'),
      runStatus: runStatus,
      runStateAdmissible: runStateAdmissible,
      attemptId: _text(json, 'attempt_id'),
      attemptState: attemptState,
      attemptStateAdmissible: attemptStateAdmissible,
      commandId: _text(json, 'command_id'),
      intentTargetId: _text(json, 'intent_target_id'),
      leaseEpoch: leaseEpoch,
      leaseActive: _bool(json, 'lease_active'),
      evaluatedAtMs: evaluatedAtMs,
      candidateCount: candidateCount,
      declarativeReadyCount: declarativeReadyCount,
      declarativePreflightReady: declarativePreflightReady,
      rejectionReasons: List.unmodifiable(rejectionReasons),
      selectedTargetId: null,
      previewOnly: true,
      authority: Map.unmodifiable(values),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': expectedEvaluationMode,
    'owner': {'issuer': issuer, 'subject': subject, 'tenant_id': tenantId},
    'conversation_id': conversationId,
    'run_id': runId,
    'run_status': runStatus,
    'run_state_admissible': runStateAdmissible,
    'attempt_id': attemptId,
    'attempt_state': attemptState,
    'attempt_state_admissible': attemptStateAdmissible,
    'command_id': commandId,
    'intent_target_id': intentTargetId,
    'lease_epoch': leaseEpoch,
    'lease_active': leaseActive,
    'evaluated_at_ms': evaluatedAtMs,
    'candidate_count': candidateCount,
    'declarative_ready_count': declarativeReadyCount,
    'declarative_preflight_ready': declarativePreflightReady,
    'rejection_reasons': rejectionReasons,
    'selected_target_id': selectedTargetId,
    'preview_only': previewOnly,
    'authority': authority,
  };

  bool isFor(String conversationID, String runID) =>
      conversationId == conversationID && runId == runID;

  bool get isDisplayOnly =>
      evaluationMode == expectedEvaluationMode &&
      previewOnly &&
      selectedTargetId == null &&
      authority.values.every((value) => !value);

  static void _exactKeys(Map object, Set<String> expected, String label) {
    final actual = object.keys.map((key) => key.toString()).toSet();
    if (actual.length != expected.length || !actual.containsAll(expected)) {
      throw FormatException('unknown or missing $label field');
    }
  }

  static Map<String, dynamic> _object(Map json, String key) {
    final value = json[key];
    if (value is! Map) throw FormatException('$key must be an object');
    return Map<String, dynamic>.from(value);
  }

  static String _text(Map json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key must be text');
    }
    return value;
  }

  static bool _bool(Map json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('$key must be bool');
    return value;
  }

  static int _positiveInt(Map json, String key) {
    final value = json[key];
    if (value is! int || value <= 0) {
      throw FormatException('$key must be positive');
    }
    return value;
  }

  static int _boundedInt(Map json, String key, int maximum) {
    final value = json[key];
    if (value is! int || value < 0 || value > maximum) {
      throw FormatException('$key is out of range');
    }
    return value;
  }

  static List<String> _stringList(Map json, String key) {
    final value = json[key];
    if (value is! List ||
        value.length > 4 ||
        value.any((item) => item is! String)) {
      throw FormatException('$key must be a string list');
    }
    final result = value.cast<String>().toList(growable: false);
    final sorted = [...result]..sort();
    if (sorted.length != result.length ||
        sorted.join('\u0000') != result.join('\u0000') ||
        result.toSet().length != result.length) {
      throw FormatException('$key must be sorted and unique');
    }
    return List.unmodifiable(result);
  }

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

// jsonDecode follows JavaScript semantics and silently keeps the last value
// for duplicate object keys. Scan strings and object nesting so a fixture
// cannot smuggle two values for a contract field into the consumer.
void _rejectDuplicateObjectKeys(String source) {
  final stack = <Set<String>>[];
  var inString = false;
  var escaped = false;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (inString) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      continue;
    }
    if (char == '{') {
      stack.add(<String>{});
      continue;
    }
    if (char == '}') {
      if (stack.isNotEmpty) stack.removeLast();
      continue;
    }
    if (char != '"' || stack.isEmpty) continue;
  }
  // A full duplicate-key parse is performed by the strict map checks above
  // for decoded objects; textual duplicates are handled by the parser below.
  final keyPattern = RegExp(r'"((?:\\.|[^"\\])*)"\s*:');
  final scopes = <int, Set<String>>{};
  for (final match in keyPattern.allMatches(source)) {
    final key = jsonDecode('"${match.group(1)}"') as String;
    final before = source.substring(0, match.start);
    final depth = '{'.allMatches(before).length - '}'.allMatches(before).length;
    if (depth > 0) {
      final keys = scopes.putIfAbsent(depth, () => <String>{});
      if (!keys.add(key)) throw FormatException('duplicate object key: $key');
    }
  }
}
