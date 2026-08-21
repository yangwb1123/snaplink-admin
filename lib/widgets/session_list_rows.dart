import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/format_helpers.dart';

/// Renders a single session row with its UA-derived meta lines.
/// [busy] 置位时行尾换成 spinner（撤销进行中，防重入）。
Widget sessionTile(
  BuildContext context,
  dynamic s,
  Future<void> Function(String) onRevoke, {
  bool busy = false,
}) {
  final id = s['id']?.toString() ?? '';
  final metaParts = <String>[];
  if (s['created_at'] != null) {
    metaParts.add(
      context.tr('since {date}', {
        'date': formatServerTime(s['created_at'], dateOnly: true),
      }),
    );
  }
  if (s['expires_at'] != null) {
    metaParts.add(
      context.tr('expires {date}', {
        'date': formatServerTime(s['expires_at'], dateOnly: true),
      }),
    );
  }
  final devParts = <String>[];
  if (s['ip'] != null) {
    devParts.add(s['ip'].toString());
  }
  if (s['user_agent'] != null) {
    devParts.add(deviceHint(context, s['user_agent'].toString()));
  }
  if (s['device_name']?.toString().isNotEmpty == true) {
    devParts.add(s['device_name'].toString());
  }
  final posture = <String>[
    if (s['device_platform']?.toString().isNotEmpty == true)
      s['device_platform'].toString(),
    if (s['device_browser']?.toString().isNotEmpty == true)
      s['device_browser'].toString(),
    if (s['trust_label']?.toString().isNotEmpty == true)
      context.tr('trust {value}', {'value': s['trust_label']}),
  ];
  return ListTile(
    title: Text(id),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in [metaParts, devParts, posture])
          if (part.isNotEmpty) Text(part.join(' · ')),
      ],
    ),
    isThreeLine: metaParts.isNotEmpty && devParts.isNotEmpty,
    trailing: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : TextButton(
            onPressed: () => onRevoke(id),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(context.tr('Revoke')),
          ),
  );
}

/// Reduces a raw User-Agent to a friendly "Browser on OS" label, ported
/// verbatim (same regexes/precedence) from app.js's deviceHint().
String deviceHint(BuildContext context, String ua) {
  final browser = ua.contains('Edg/')
      ? 'Edge'
      : ua.contains('Chrome/')
      ? 'Chrome'
      : ua.contains('Firefox/')
      ? 'Firefox'
      : ua.contains('Safari/')
      ? 'Safari'
      : '';
  final os = ua.contains('Windows')
      ? 'Windows'
      : ua.contains('Mac OS X') || ua.contains('Macintosh')
      ? 'macOS'
      : ua.contains('Android')
      ? 'Android'
      : ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iOS')
      ? 'iOS'
      : ua.contains('Linux')
      ? 'Linux'
      : '';
  if (browser.isNotEmpty && os.isNotEmpty) {
    return context.tr('{browser} on {os}', {'browser': browser, 'os': os});
  }
  if (browser.isNotEmpty) return browser;
  if (os.isNotEmpty) return os;
  return ua.length > 40 ? '${ua.substring(0, 40)}…' : ua;
}
