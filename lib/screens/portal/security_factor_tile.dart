import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// A single MFA factor tile showing method, label, and remove button.
/// The leading icon is tinted with the portal brand color
/// (`colorScheme.primary`) — admin group colors do not apply to portal
/// surfaces. Removal stays a plain-text danger action; the caller owns the
/// shared confirm dialog so removal semantics are unchanged.
class SecurityFactorTile extends StatelessWidget {
  final Map factor;
  final bool busy;
  final void Function(String id) onRemove;

  const SecurityFactorTile({
    super.key,
    required this.factor,
    required this.busy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final id = factor['id']?.toString() ?? '';
    final method = factor['method']?.toString() ?? '';
    var meta = method;
    if (factor['added_at'] != null) {
      final addedAt = factor['added_at'].toString();
      meta += context.tr(' · added {date}', {
        'date': addedAt.substring(0, addedAt.length < 10 ? addedAt.length : 10),
      });
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_methodIcon(method), size: 18, color: accent),
      ),
      title: Text(
        factor['label']?.toString() ?? method,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        meta,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: TextButton(
        onPressed: busy ? null : () => onRemove(id),
        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        child: Text(context.tr('Remove')),
      ),
    );
  }
}

/// Per-method leading icon. API `method` values are rendered as icons only
/// (never passed through i18n — X10: API values bypass the copy catalog).
IconData _methodIcon(String method) => switch (method) {
  'totp' => Icons.pin_outlined,
  'webauthn' => Icons.fingerprint,
  'passkey' => Icons.fingerprint,
  'push' => Icons.notifications_active_outlined,
  'sms' => Icons.sms_outlined,
  'email' => Icons.mail_outline,
  'recovery' => Icons.assignment_outlined,
  _ => Icons.shield_outlined,
};
