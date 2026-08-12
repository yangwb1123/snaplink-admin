import 'package:flutter/widgets.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Localized, human-readable client-secret expiry label (table cells,
/// info rows and rotation dialogs). Pure data rendering via `context.tr`
/// keys with `{days}`/`{date}` placeholders — never fed back into
/// `LocalizedText` as a dynamic key (X1/X10 pattern).
String clientSecretExpiryLabel(BuildContext context, Map<String, dynamic>? client) {
  final seconds = clientSecretExpiryUnix(client);
  if (seconds <= 0) return context.tr('Never expires');
  final expiry = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
  final remaining = expiry.difference(DateTime.now());
  final date = expiry.toIso8601String().split('T').first;
  if (remaining.isNegative) {
    return context.tr('Expired on {date}', {'date': date});
  }
  if (remaining <= const Duration(days: 30)) {
    final days = remaining.inDays < 1 ? '<1' : '${remaining.inDays}';
    return context.tr(
      'Expires in {days} day(s) · {date}',
      {'days': days, 'date': date},
    );
  }
  return context.tr('Expires {date}', {'date': date});
}

/// Raw unix-seconds expiry from an API response; 0 = never expires.
int clientSecretExpiryUnix(Map<String, dynamic>? response) {
  final raw = response?['client_secret_expires_at'];
  return raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
}
