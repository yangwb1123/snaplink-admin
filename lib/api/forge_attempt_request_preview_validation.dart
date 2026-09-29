part of 'forge_attempt_request_preview.dart';

Map<String, dynamic> _attemptRequestObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Forge Attempt request $label must be an object.');
  }
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _attemptRequestExactKeys(
  Map<String, dynamic> value,
  Set<String> expected,
) {
  if (value.keys.toSet().length != value.length ||
      value.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(value.keys.toSet()).isNotEmpty) {
    throw const FormatException(
      'Forge Attempt request fixture has unknown or missing fields.',
    );
  }
}

bool _attemptRequestBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Forge Attempt request flag must be boolean.');
  }
  return value;
}

String _attemptRequestText(Object? value, String label) {
  if (value is! String || value.isEmpty || value.length > 512) {
    throw FormatException('Invalid Forge Attempt request $label.');
  }
  return value;
}

String _attemptRequestError(Object? value) {
  if (value is! String || value.length > 64) {
    throw const FormatException('Invalid Forge Attempt request error.');
  }
  return value;
}

List<String> _attemptRequestTextList(
  Object? value,
  String label, {
  bool allowEmpty = false,
  required bool sortAndRequireUnique,
}) {
  if (value is! List || (!allowEmpty && value.isEmpty) || value.length > 64) {
    throw FormatException('Invalid Forge Attempt request $label.');
  }
  final result = value.map((item) => _attemptRequestText(item, label)).toList();
  if (sortAndRequireUnique) {
    final sorted = [...result]..sort();
    if (sorted.join('\u0000') != result.join('\u0000') ||
        sorted.toSet().length != result.length) {
      throw FormatException(
        'Forge Attempt request $label must be sorted and unique.',
      );
    }
  }
  return result;
}

void _validateRequest(Object? value) {
  final request = _attemptRequestObject(value, 'request');
  _attemptRequestExactKeys(request, {
    'scope_ref',
    'attempt_ref',
    'work_item_ref',
    'project_ref',
    'project_snapshot_ref',
    'control_versions',
    'executor',
    'context_artifact_ref',
    'workspace_capability_ref',
    'grant_ref',
    'approval_refs',
    'requested_effects',
    'budget',
    'timeout_ms',
    'idempotency_key',
  });
  _validateScope(request['scope_ref']);
  for (final key in const [
    'attempt_ref',
    'work_item_ref',
    'project_ref',
    'project_snapshot_ref',
  ]) {
    _validateEntityRef(request[key]);
  }
  _validateControlVersions(request['control_versions']);
  _validateExecutor(request['executor']);
  _validateArtifact(request['context_artifact_ref']);
  _validateRecord(request['workspace_capability_ref']);
  _validateRecord(request['grant_ref']);
  final approvalRefs = request['approval_refs'];
  if (approvalRefs is! List || approvalRefs.length > 64) {
    throw const FormatException('Invalid Forge Attempt request approvals.');
  }
  for (final ref in approvalRefs) {
    _validateRecord(ref);
  }
  _attemptRequestTextList(
    request['requested_effects'],
    'requested_effects',
    allowEmpty: true,
    sortAndRequireUnique: false,
  );
  _validateBudget(request['budget']);
  _attemptRequestNonNegativeInt(request['timeout_ms'], 'timeout_ms');
  _attemptRequestText(request['idempotency_key'], 'idempotency_key');
}

void _validateScope(Object? value) {
  final json = _attemptRequestObject(value, 'scope_ref');
  _attemptRequestExactKeys(json, {
    'action_id',
    'attempt_id',
    'change_id',
    'objective_id',
    'project_id',
    'project_snapshot_id',
    'session_id',
    'space_id',
    'turn_id',
    'work_graph_id',
    'work_item_id',
  });
  for (final entry in json.entries) {
    if (entry.value != null) _attemptRequestText(entry.value, entry.key);
  }
}

void _validateEntityRef(Object? value) {
  final json = _attemptRequestObject(value, 'entity_ref');
  _attemptRequestExactKeys(json, {'entity_id', 'entity_type'});
  _attemptRequestText(json['entity_id'], 'entity_id');
  _attemptRequestText(json['entity_type'], 'entity_type');
}

void _validateControlVersions(Object? value) {
  final json = _attemptRequestObject(value, 'control_versions');
  _attemptRequestExactKeys(json, {
    'objective_version',
    'change_version',
    'work_graph_version',
    'work_item_version',
  });
  for (final entry in json.entries) {
    // Rejected fixture cases intentionally carry zero values so the client
    // can display the stable domain rejection without resolving references.
    _attemptRequestNonNegativeInt(entry.value, entry.key);
  }
}

void _validateExecutor(Object? value) {
  final json = _attemptRequestObject(value, 'executor');
  _attemptRequestExactKeys(json, {
    'actor_ref',
    'adapter_id',
    'adapter_version',
  });
  final actor = _attemptRequestObject(json['actor_ref'], 'actor_ref');
  _attemptRequestExactKeys(actor, {'actor_id', 'actor_type'});
  _attemptRequestText(actor['actor_id'], 'actor_id');
  _attemptRequestText(actor['actor_type'], 'actor_type');
  _attemptRequestText(json['adapter_id'], 'adapter_id');
  _attemptRequestText(json['adapter_version'], 'adapter_version');
}

void _validateArtifact(Object? value) {
  if (value == null) return;
  final json = _attemptRequestObject(value, 'context_artifact_ref');
  _attemptRequestExactKeys(json, {
    'artifact_kind',
    'canonicalization',
    'content_digest',
    'content_id',
    'created_at_unix_ms',
    'logical_id',
    'media_type',
    'producer_attempt_id',
    'provenance_ref',
    'retention_class',
    'sensitivity',
    'size_bytes',
    'source_snapshot_ref',
  });
  for (final key in const [
    'artifact_kind',
    'canonicalization',
    'content_digest',
    'content_id',
    'logical_id',
    'media_type',
    'producer_attempt_id',
    'retention_class',
    'sensitivity',
  ]) {
    _attemptRequestText(json[key], key);
  }
  _attemptRequestPositiveInt(json['created_at_unix_ms'], 'created_at_unix_ms');
  _attemptRequestNonNegativeInt(json['size_bytes'], 'size_bytes');
  _validateRecord(json['provenance_ref']);
  _validateEntityRef(json['source_snapshot_ref']);
}

String _validateRecord(Object? value) {
  if (value == null) return '';
  final json = _attemptRequestObject(value, 'record_ref');
  _attemptRequestExactKeys(json, {'record_id', 'record_sha256', 'record_type'});
  final id = _attemptRequestText(json['record_id'], 'record_id');
  _attemptRequestText(json['record_sha256'], 'record_sha256');
  _attemptRequestText(json['record_type'], 'record_type');
  return id;
}

void _validateBudget(Object? value) {
  final json = _attemptRequestObject(value, 'budget');
  _attemptRequestExactKeys(json, {
    'max_duration_ms',
    'max_cost_usd_micros',
    'max_model_calls',
    'max_tool_calls',
    'max_input_tokens',
    'max_output_tokens',
    'max_output_bytes',
    'max_network_bytes',
  });
  for (final entry in json.entries) {
    _attemptRequestNonNegativeInt(entry.value, entry.key);
  }
}

void _attemptRequestPositiveInt(Object? value, String label) {
  if (value is! int || value < 1 || value > 9007199254740991) {
    throw FormatException('Invalid Forge Attempt request $label.');
  }
}

void _attemptRequestNonNegativeInt(Object? value, String label) {
  if (value is! int || value < 0 || value > 9007199254740991) {
    throw FormatException('Invalid Forge Attempt request $label.');
  }
}

Object? _decodeAttemptRequestJson(String source) {
  try {
    // jsonDecode is deliberately called only after duplicate-key scanning.
    return _jsonDecode(source);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Invalid Forge Attempt request JSON.');
  }
}

Object? _jsonDecode(String source) {
  return jsonDecode(source);
}

void _rejectAttemptRequestDuplicateKeys(String source) {
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
          // The key text is decoded after the string boundary to handle
          // escaped names consistently with dart:convert.
          final key = _jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Duplicate Forge Attempt request JSON key.',
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
        throw const FormatException('Invalid Forge Attempt request JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge Attempt request JSON.');
  }
}
