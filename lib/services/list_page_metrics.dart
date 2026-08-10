/// Pure page-aggregate helpers for list metrics (zero Flutter imports).
///
/// All aggregates are computed from the CURRENT PAGE payload only; the
/// server `totalSize` is carried separately and labeled "Total". Reads are
/// null-safe (`is`-checks / `?? 0` — a bare `as num` would throw on
/// malformed rows).
library;

import 'package:sso_admin/api/audit_event_row.dart';

class ClientPageMetrics {
  final int active;
  final int inactive;
  final int secretsExpiring;

  const ClientPageMetrics({
    required this.active,
    required this.inactive,
    required this.secretsExpiring,
  });
}

/// active = `row['active'] == true`; secretsExpiring = a positive
/// `client_secret_expires_at` on the page (the list payload cannot
/// distinguish pending from inactive — honest wire-shape reading).
ClientPageMetrics clientPageMetrics(List<Map<String, dynamic>> items) {
  var active = 0;
  var inactive = 0;
  var secretsExpiring = 0;
  for (final row in items) {
    if (row['active'] == true) {
      active++;
    } else {
      inactive++;
    }
    final expiry = row['client_secret_expires_at'];
    if ((expiry is num ? expiry : int.tryParse('$expiry') ?? 0) > 0) {
      secretsExpiring++;
    }
  }
  return ClientPageMetrics(
    active: active,
    inactive: inactive,
    secretsExpiring: secretsExpiring,
  );
}

/// Distinct provider → page count.
Map<String, int> userProviderCounts(List<Map<String, dynamic>> items) {
  final counts = <String, int>{};
  for (final row in items) {
    final provider = row['provider']?.toString() ?? 'unknown';
    counts.update(provider, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

class TenantPageMetrics {
  final int active;
  final int suspended;

  const TenantPageMetrics({required this.active, required this.suspended});
}

/// `status == 'suspended'` else active (matches the list STATUS column).
TenantPageMetrics tenantPageMetrics(List<Map<String, dynamic>> items) {
  var active = 0;
  var suspended = 0;
  for (final row in items) {
    if (row['status']?.toString() == 'suspended') {
      suspended++;
    } else {
      active++;
    }
  }
  return TenantPageMetrics(active: active, suspended: suspended);
}

class AuditPageMetrics {
  final int entries;
  final int errors;
  final int eventTypes;

  const AuditPageMetrics({
    required this.entries,
    required this.errors,
    required this.eventTypes,
  });
}

/// errors = rows with outcome == 'failure'; eventTypes = distinct types.
AuditPageMetrics auditPageMetrics(List<AuditEventRow> rows) {
  var errors = 0;
  final types = <String>{};
  for (final row in rows) {
    if (row.outcome == 'failure') errors++;
    if (row.type.isNotEmpty) types.add(row.type);
  }
  return AuditPageMetrics(
    entries: rows.length,
    errors: errors,
    eventTypes: types.length,
  );
}
