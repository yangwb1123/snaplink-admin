part of 'forge_device_inventory_placement_evaluation.dart';

Map<String, dynamic> _inventoryEvaluationObject(Object? value) {
  if (value is! Map) {
    throw const FormatException(
      'Expected Forge persisted placement-evaluation object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _inventoryEvaluationExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge persisted placement-evaluation fields.',
    );
  }
}

bool _inventoryEvaluationBool(Object? value) {
  if (value is! bool) {
    throw const FormatException(
      'Invalid Forge persisted placement-evaluation boolean.',
    );
  }
  return value;
}

String _inventoryEvaluationError(Object? value) {
  if (value is! String || value.trim() != value || value.length > 128) {
    throw const FormatException(
      'Invalid Forge persisted placement-evaluation error.',
    );
  }
  return value;
}

bool _inventoryEvaluationKnownError(String value) => const {
  'unsupported_persisted_placement_capability',
  'missing_persisted_placement_decision',
  'invalid_persisted_inventory_placement_input',
  'invalid_request',
}.contains(value);

String _inventoryEvaluationIdentifier(Object? value) {
  if (value is! String || value.isEmpty || value.length > 128) {
    throw const FormatException(
      'Invalid Forge persisted placement-evaluation identifier.',
    );
  }
  final codes = value.codeUnits;
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) ||
      code == 0x2e ||
      code == 0x5f ||
      code == 0x3a ||
      code == 0x2d;
  if (!first(codes.first) || !codes.skip(1).every(rest)) {
    throw const FormatException(
      'Invalid Forge persisted placement-evaluation identifier.',
    );
  }
  return value;
}

List<String> _inventoryEvaluationReasons(Object? value) {
  if (value is! List || value.length > 64) {
    throw const FormatException(
      'Invalid Forge persisted placement-evaluation reasons.',
    );
  }
  final reasons = value.map(_inventoryEvaluationReason).toList(growable: false);
  for (var index = 1; index < reasons.length; index++) {
    if (reasons[index - 1].compareTo(reasons[index]) >= 0) {
      throw const FormatException(
        'Unsorted Forge persisted placement-evaluation reasons.',
      );
    }
  }
  return reasons;
}

String _inventoryEvaluationReason(Object? value) {
  const reasons = {
    'tenant_mismatch',
    'approval_pending',
    'device_revoked',
    'device_cordoned',
    'runner_offline',
    'declared_offline',
    'heartbeat_observed_in_future',
    'heartbeat_stale',
    'snapshot_declared_from_future',
    'snapshot_stale',
    'capability_lease_expired',
    'capability_lease_invalid',
    'declared_lease_expired',
    'os_mismatch',
    'architecture_mismatch',
    'cpu_cores_insufficient',
    'memory_insufficient',
    'memory_capacity_insufficient',
    'storage_insufficient',
    'storage_capacity_insufficient',
    'runtime_missing',
    'runtime_unavailable',
    'gpu_missing',
    'gpu_count_insufficient',
    'gpu_memory_insufficient',
    'gpu_runtime_mismatch',
    'data_residency_zone_mismatch',
    'trust_zone_unconfirmed',
    'trust_zone_below_minimum',
    'sandbox_floor_unmet',
    'concurrency_capacity_insufficient',
  };
  if (value is! String || !reasons.contains(value)) {
    throw const FormatException(
      'Invalid Forge persisted placement-evaluation reason.',
    );
  }
  return value;
}

int _inventoryEvaluationSafePositiveInt(Object? value) {
  if (value is! int || value <= 0 || value > 9007199254740991) {
    throw const FormatException(
      'Invalid Forge persisted placement-evaluation integer.',
    );
  }
  return value;
}

void _inventoryEvaluationRejectDuplicateKeys(String source) {
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
        while (next < source.length &&
            _inventoryEvaluationWhitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException(
              'Invalid Forge placement-evaluation JSON object key.',
            );
          }
          final decoded = jsonDecode(source.substring(stringStart, index + 1));
          if (decoded is! String || !objects.last.add(decoded)) {
            throw const FormatException(
              'Duplicate Forge placement-evaluation JSON key.',
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
        throw const FormatException('Invalid Forge placement-evaluation JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge placement-evaluation JSON.');
  }
}

bool _inventoryEvaluationWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
