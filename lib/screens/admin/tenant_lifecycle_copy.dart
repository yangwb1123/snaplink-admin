/// Operator copy for tenant lifecycle actions and their exact credential
/// revocation report.
///
/// The returned strings use `$` interpolation for API values, so callers keep
/// passing them straight to `LocalizedText` (gate-blind per the i18n gate's
/// `$`-skip rule — these render verbatim for zh). Only the action words
/// (`Tenant suspended.` / `Tenant deleted.`) are catalog-translated by the
/// caller before being substituted in.
abstract final class TenantLifecycleCopy {
  static String confirmation(String id, String next) => next == 'suspended'
      ? 'Suspend $id? New access is blocked and Snaplink will report every '
            'refresh-token and session revocation result with a stable retry '
            'key for any failed item.'
      : 'Return $id to active service?';

  static String deletion(String id, String label) =>
      'Delete $label ($id)? This cannot be undone. Snaplink will return the '
      'exact refresh-token and session revocation report.';

  static String result(String action, Map<String, dynamic> response) {
    final value = response['credential_revocation'];
    if (value is! Map) {
      return '$action No credential-revocation report was returned.';
    }
    final report = Map<String, dynamic>.from(value);
    final refreshTokens = _count(report['refresh_tokens_revoked']);
    final sessions = _count(report['sessions_revoked']);
    final results = report['results'] is List
        ? (report['results'] as List).whereType<Map>().toList()
        : const <Map>[];
    final failed = results.where((item) => item['status'] != 'revoked').length;
    if (report['complete'] == true && failed == 0) {
      return '$action Revoked $refreshTokens refresh tokens and $sessions '
          'sessions; every reported credential operation completed.';
    }
    return '$action Revoked $refreshTokens refresh tokens and $sessions '
        'sessions, but $failed credential operations failed. Retry only the '
        'reported idempotency keys.';
  }

  static int _count(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
