/// Operator copy for tenant lifecycle result reports.
abstract final class TenantLifecycleCopy {
  static ({String key, Map<String, Object?> args}) resultCopy(
    String action,
    Map<String, dynamic> response,
  ) {
    final value = response['credential_revocation'];
    if (value is! Map) {
      return (
        key: '{action} No credential-revocation report was returned.',
        args: {'action': action},
      );
    }
    final report = Map<String, dynamic>.from(value);
    final refreshTokens = _count(report['refresh_tokens_revoked']);
    final sessions = _count(report['sessions_revoked']);
    final results = report['results'] is List
        ? (report['results'] as List).whereType<Map>().toList()
        : const <Map>[];
    final failed = results.where((item) => item['status'] != 'revoked').length;
    if (report['complete'] == true && failed == 0) {
      return (
        key:
            '{action} Revoked {refreshTokens} refresh tokens and {sessions} sessions; every reported credential operation completed.',
        args: {
          'action': action,
          'refreshTokens': refreshTokens,
          'sessions': sessions,
        },
      );
    }
    return (
      key:
          '{action} Revoked {refreshTokens} refresh tokens and {sessions} sessions, but {failed} credential operations failed. Retry only the reported idempotency keys.',
      args: {
        'action': action,
        'refreshTokens': refreshTokens,
        'sessions': sessions,
        'failed': failed,
      },
    );
  }

  static int _count(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
