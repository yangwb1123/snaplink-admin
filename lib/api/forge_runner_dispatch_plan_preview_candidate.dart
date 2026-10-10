part of 'forge_runner_dispatch_plan_preview.dart';

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
