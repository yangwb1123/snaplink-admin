/// Normalizes the tenant-metering wire shape across Snaplink versions.
///
/// Current Snaplink source returns `metering.TenantUsage` directly. That Go
/// struct has no JSON tags, so its real JSON keys are PascalCase even though
/// the admin contract and console use snake_case. Keep both shapes readable
/// until the backend adds explicit tags.
Map<String, dynamic> normalizeTenantUsageRecord(Map<dynamic, dynamic> value) {
  final record = <String, dynamic>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
  const aliases = <String, String>{
    'TenantID': 'tenant_id',
    'Period': 'period',
    'PeriodStart': 'period_start',
    'Logins': 'logins',
    'TokensIssued': 'tokens_issued',
    'ActiveUsers': 'active_users',
    'ActiveClients': 'active_clients',
    'MFAChallenges': 'mfa_challenges',
  };
  for (final alias in aliases.entries) {
    if (!record.containsKey(alias.value) && record.containsKey(alias.key)) {
      record[alias.value] = record[alias.key];
    }
  }
  return record;
}

Map<String, dynamic> normalizeTopTenantsPayload(Map<String, dynamic> payload) {
  final raw = payload['tenants'];
  if (raw is! List) return payload;
  return {
    ...payload,
    'tenants': raw
        .whereType<Map>()
        .map(normalizeTenantUsageRecord)
        .toList(growable: false),
  };
}

String formatUsageMetricSummary(Map<dynamic, dynamic> tenant) {
  const fields = [
    ('logins', 'logins'),
    ('tokens_issued', 'tokens'),
    ('active_users', 'active users'),
    ('active_clients', 'active clients'),
    ('mfa_challenges', 'MFA challenges'),
  ];
  return fields
      .where((field) => tenant[field.$1] != null)
      .map((field) => '${tenant[field.$1]} ${field.$2}')
      .join(' · ');
}

/// Sums a numeric tenant-metric field across normalized usage records.
/// Missing/unknown fields count as zero, so only reported metrics contribute
/// to the headline cards (data-honesty: never fabricate a total).
int sumTenantMetric(
  List<Map<dynamic, dynamic>> tenants,
  String field,
) => tenants.fold<int>(
  0,
  (sum, tenant) => sum + ((tenant[field] as num?) ?? 0).toInt(),
);
