part of 'forge_device_inventory_placement_batch_evaluation.dart';

Map<String, dynamic> _batchEvaluationObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge placement-batch object.');
  }
  return Map<String, dynamic>.from(value);
}

void _batchEvaluationExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge placement-batch fields.');
  }
}

void _batchEvaluationValidateEnvelope(Map<String, dynamic> json) {
  if (json['schema_version'] !=
          forgeDeviceInventoryPlacementBatchEvaluationSchema ||
      json['evaluation_mode'] !=
          forgeDeviceInventoryPlacementBatchEvaluationMode ||
      json['source_fixture'] !=
          forgeDeviceInventoryPlacementBatchEvaluationSourceFixture ||
      !_batchEvaluationBool(json['empty_inputs_allowed']) ||
      json['selected_device_id'] != null ||
      json['selected_instance_id'] != null) {
    throw const FormatException('Invalid Forge placement-batch envelope.');
  }
}

List<ForgeDeviceInventoryPlacementBatchCase> _batchEvaluationCases(
  Object? value,
) {
  if (value is! List ||
      value.length != 6 ||
      value.length > forgeDeviceInventoryPlacementBatchEvaluationMaxCases) {
    throw const FormatException('Invalid Forge placement-batch cases.');
  }
  final cases = value
      .map(ForgeDeviceInventoryPlacementBatchCase.fromJson)
      .toList(growable: false);
  final names = <String>{};
  final devices = <String>{};
  final instances = <String>{};
  for (final item in cases) {
    if (!names.add(item.name) ||
        !devices.add(item.deviceID) ||
        !instances.add(item.instanceID)) {
      throw const FormatException('Duplicate Forge placement-batch identity.');
    }
    if (item.expected.deviceID != item.deviceID ||
        item.expected.instanceID != item.instanceID) {
      throw const FormatException(
        'Mismatched Forge placement-batch decision identity.',
      );
    }
    const sourceCases = {
      'online': 'online',
      'pending': 'pending',
      'expired': 'expired',
      'stale': 'stale',
      'offline': 'offline',
      'future': 'online',
    };
    if (sourceCases[item.name] != item.sourceCase) {
      throw const FormatException(
        'Mismatched Forge placement-batch source case.',
      );
    }
  }
  for (var index = 1; index < cases.length; index++) {
    if (cases[index - 1].deviceID.compareTo(cases[index].deviceID) >= 0) {
      throw const FormatException('Unsorted Forge placement-batch decisions.');
    }
  }
  return List.unmodifiable(cases);
}

List<ForgeDeviceInventoryPlacementBatchErrorCase> _batchEvaluationErrorCases(
  Object? value,
) {
  if (value is! List || value.length != 4 || value.length > 16) {
    throw const FormatException('Invalid Forge placement-batch error cases.');
  }
  final cases = value
      .map(ForgeDeviceInventoryPlacementBatchErrorCase.fromJson)
      .toList(growable: false);
  final names = <String>{};
  for (final item in cases) {
    if (!names.add(item.name)) {
      throw const FormatException(
        'Duplicate Forge placement-batch error case.',
      );
    }
    if (_batchEvaluationExpectedError(item.name) != item.error) {
      throw const FormatException('Mismatched Forge placement-batch error.');
    }
  }
  return List.unmodifiable(cases);
}

String _batchEvaluationExpectedError(String name) => switch (name) {
  'owner_mismatch' => 'owner_mismatch',
  'duplicate_device' ||
  'duplicate_instance' ||
  'invalid_evaluated_at' => 'invalid_persisted_inventory_placement_input',
  _ => throw const FormatException('Unknown Forge placement-batch error case.'),
};

bool _batchEvaluationBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge placement-batch boolean.');
  }
  return value;
}

String _batchEvaluationError(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge placement-batch error.');
  }
  return value;
}

bool _batchEvaluationKnownError(String value) => const {
  'owner_mismatch',
  'invalid_persisted_inventory_placement_input',
  'unsupported_persisted_placement_capability',
}.contains(value);

String _batchEvaluationIdentifier(Object? value) {
  if (value is! String || value.isEmpty || value.length > 128) {
    throw const FormatException('Invalid Forge placement-batch identifier.');
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
    throw const FormatException('Invalid Forge placement-batch identifier.');
  }
  return value;
}

String _batchEvaluationCaseName(Object? value) {
  final name = _batchEvaluationIdentifier(value);
  if (!const {
    'online',
    'pending',
    'expired',
    'stale',
    'offline',
    'future',
  }.contains(name)) {
    throw const FormatException('Unknown Forge placement-batch case.');
  }
  return name;
}

String _batchEvaluationSourceCase(Object? value) {
  final sourceCase = _batchEvaluationIdentifier(value);
  if (!const {
    'online',
    'pending',
    'expired',
    'stale',
    'offline',
  }.contains(sourceCase)) {
    throw const FormatException('Unknown Forge placement-batch source case.');
  }
  return sourceCase;
}

String _batchEvaluationErrorCaseName(Object? value) {
  final name = _batchEvaluationIdentifier(value);
  if (!const {
    'owner_mismatch',
    'duplicate_device',
    'duplicate_instance',
    'invalid_evaluated_at',
  }.contains(name)) {
    throw const FormatException('Unknown Forge placement-batch error case.');
  }
  return name;
}

List<String> _batchEvaluationReasons(Object? value) {
  if (value is! List || value.length > 64) {
    throw const FormatException('Invalid Forge placement-batch reasons.');
  }
  final reasons = value.map(_batchEvaluationReason).toList(growable: false);
  for (var index = 1; index < reasons.length; index++) {
    if (reasons[index - 1].compareTo(reasons[index]) >= 0) {
      throw const FormatException('Unsorted Forge placement-batch reasons.');
    }
  }
  return reasons;
}

String _batchEvaluationReason(Object? value) {
  const reasons = {
    'tenant_mismatch',
    'approval_pending',
    'device_revoked',
    'device_cordoned',
    'declared_offline',
    'snapshot_declared_from_future',
    'snapshot_stale',
    'declared_lease_expired',
    'declared_lease_invalid',
    'os_mismatch',
    'architecture_mismatch',
    'cpu_cores_insufficient',
    'memory_insufficient',
    'storage_insufficient',
    'runtime_missing',
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
    throw const FormatException('Invalid Forge placement-batch reason.');
  }
  return value;
}

int _batchEvaluationPositiveSafeInt(Object? value) {
  if (value is! int || value <= 0 || value > 9007199254740991) {
    throw const FormatException('Invalid Forge placement-batch integer.');
  }
  return value;
}

void _batchEvaluationRejectDuplicateKeys(String source) {
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
            _batchEvaluationWhitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException(
              'Invalid Forge placement-batch JSON object key.',
            );
          }
          final decoded = jsonDecode(source.substring(stringStart, index + 1));
          if (decoded is! String || !objects.last.add(decoded)) {
            throw const FormatException(
              'Duplicate Forge placement-batch JSON key.',
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
        throw const FormatException('Invalid Forge placement-batch JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge placement-batch JSON.');
  }
}

bool _batchEvaluationWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
