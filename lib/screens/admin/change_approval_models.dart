import 'dart:convert';

Map<String, dynamic> normalizeChangeApproval(Map<dynamic, dynamic> raw) {
  Object? field(String snake, String pascal) => raw[snake] ?? raw[pascal];

  return <String, dynamic>{
    'id': field('id', 'ID')?.toString() ?? '',
    'action_type': field('action_type', 'ActionType')?.toString() ?? '',
    'payload': _decodePayload(field('payload', 'Payload')),
    'reason': field('reason', 'Reason')?.toString() ?? '',
    'proposed_by': field('proposed_by', 'ProposedBy')?.toString() ?? '',
    'approved_by': field('approved_by', 'ApprovedBy')?.toString() ?? '',
    'status': field('status', 'Status')?.toString() ?? 'unknown',
    'failure_note': field('failure_note', 'FailureNote')?.toString() ?? '',
    'created_at': field('created_at', 'CreatedAt')?.toString() ?? '',
    'decided_at': field('decided_at', 'DecidedAt')?.toString() ?? '',
  };
}

Map<String, dynamic> _decodePayload(Object? value) {
  if (value == null) return const {};
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List<int>) return _decodePayloadBytes(value);
  if (value is String) {
    if (value.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Go's encoding/json represents []byte as base64. Try that below.
    }
    try {
      return _decodePayloadBytes(base64Decode(value));
    } on FormatException {
      return const {'_unavailable': 'Payload could not be decoded safely.'};
    }
  }
  return const {'_unavailable': 'Payload could not be decoded safely.'};
}

Map<String, dynamic> _decodePayloadBytes(List<int> value) {
  try {
    final decoded = jsonDecode(utf8.decode(value));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException {
    // Never expose an undecodable raw/base64 payload in the admin UI.
  }
  return const {'_unavailable': 'Payload could not be decoded safely.'};
}
