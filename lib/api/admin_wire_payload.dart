/// Adapter for the published admin/v1 protobuf JSON surface.
///
/// grpc-gateway uses protojson's camelCase names and string int64 values;
/// older gateways/REST handlers use snake_case. Add the known field aliases
/// consumed by the console without changing values, deleting wire fields, or
/// traversing user-defined maps (attributes/settings/branding/config/payload).
Map<String, dynamic> adminWirePayload(
  String path,
  Map<String, dynamic> payload,
) => _isProtoRoute(path) ? _record(payload) : payload;

bool _isProtoRoute(String path) {
  final parts = Uri.parse(path).path.split('/');
  if (parts.length < 5 || parts.take(4).join('/') != '/api/v1/admin') {
    return false;
  }
  return switch (parts[4].split(':').first) {
    'clients' ||
    'domains' ||
    'keys' ||
    'permissions' ||
    'snapshots' ||
    'releases' ||
    'operations' => true,
    'users' =>
      parts.length <= 6 || (parts.length == 7 && parts.last == 'sessions'),
    'tenants' => parts.length <= 6,
    'tokens' =>
      parts.length == 6 &&
          const {'sessions', 'revoke', 'temp'}.contains(parts.last),
    _ => false,
  };
}

final _aliases = <String, String>{
  for (final field in _protoFields)
    field.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match[1]!.toUpperCase(),
    ): field,
};

// Field names from Snaplink proto/admin/v1/*.proto, not arbitrary JSON keys.
const _protoFields = {
  'next_page_token',
  'total_size',
  'redirect_uris',
  'allowed_scopes',
  'allowed_authenticators',
  'token_strategy',
  'client_secret_expires_at',
  'login_page_uri',
  'tenant_id',
  'grant_types',
  'external_id',
  'user_id',
  'client_id',
  'session_id',
  'created_at_unix',
  'expires_at_unix',
  'home_region',
  'allowed_regions',
  'enforce_writes',
  'default_client_id',
  'is_apex',
  'credential_revocation',
  'refresh_tokens_revoked',
  'sessions_revoked',
  'idempotency_key',
  'resource_id',
  'revoked_count',
  'requires_auth',
  'required_permissions',
  'require_mode',
  'created_at',
  'updated_at',
  'conflict_sets',
  'role_codes',
  'role_code',
  'old_kid',
  'new_kid',
  'grace_seconds',
  'key_class',
  'rollout_state',
  'schema_version',
  'snapshot_id',
  'taken_at_unix',
  'source_namespace',
  'source_node_id',
  'size_bytes',
  'encryption_algorithm',
  'bootstrap_applied_version',
  'stored_as',
  'resources_json',
  'dry_run',
  'operation_id',
  'safety_snapshot_id',
  'rolled_back',
  'credential_recovery',
  'mfa_reenrollment_required',
  'requires_rotation',
  'no_op',
  'config_snapshot',
  'released_at_unix',
  'released_by',
  'git_ref',
  'release_id',
  'previous_id',
  'current_step',
  'result_json',
  'started_at_unix',
  'finished_at_unix',
  'updated_at_unix',
};

// These are protobuf message fields. Unlisted maps are opaque application
// data; even a user attribute called tenantId must remain exactly that key.
const _messages = {
  'client',
  'clients',
  'user',
  'users',
  'tenant',
  'tenants',
  'domain',
  'domains',
  'session',
  'sessions',
  'role',
  'roles',
  'assignment',
  'assignments',
  'resource',
  'resources',
  'items',
  'meta',
  'report',
  'release',
  'frontend',
  'backend',
  'operation',
  'operations',
  'steps',
  'compensations',
  'credential_revocation',
  'results',
  'credential_recovery',
  'bootstrap',
  'conflict_sets',
};

Map<String, dynamic> _record(Map<String, dynamic> source) {
  final result = Map<String, dynamic>.from(source);
  for (final entry in _aliases.entries) {
    if (source.containsKey(entry.key) && !source.containsKey(entry.value)) {
      result[entry.value] = source[entry.key];
    }
  }
  for (final key in _messages) {
    if (!result.containsKey(key)) continue;
    final value = result[key];
    // RestoreReport.items is a category-name → CategoryCounts map, not a
    // message itself. Preserve category identifiers while adapting counts.
    result[key] = key == 'items' && value is Map
        ? {for (final entry in value.entries) entry.key: _node(entry.value)}
        : _node(value);
  }
  return result;
}

Object? _node(Object? value) {
  if (value is Map<String, dynamic>) return _record(value);
  if (value is List) return value.map(_node).toList(growable: false);
  return value;
}
