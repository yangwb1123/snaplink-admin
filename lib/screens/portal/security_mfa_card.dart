import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'portal_widgets.dart';
import 'security_factor_tile.dart';

/// MFA (Two-factor methods) card for the security tab. Three-state factor
/// body: loading → skeleton list; failure → inline error hint + retry; empty
/// list → inline empty hint (icons/color-coded, compact enough to keep the
/// TOTP enrollment controls inside the card viewport). TOTP enrollment keeps
/// its one-time-secret panel — the secret is only ever rendered from the
/// single `begin` response and cleared by the caller on confirm/cancel.
class SecurityMfaCard extends StatelessWidget {
  final bool mfaLoading;
  final bool mfaError;
  final bool mfaNotEnabled;
  final List factors;
  final String? mfaEmptyHint;
  final String? mfaMessage;
  final bool mfaOk;
  final bool mfaBusy;
  final bool totpPanelOpen;
  final String pendingSecret;
  final String pendingUri;
  final TextEditingController totpLabelCtrl;
  final TextEditingController totpCodeCtrl;
  final bool totpBusy;
  final String? totpMsg;
  final VoidCallback onBeginTotp;
  final VoidCallback onConfirmTotp;
  final VoidCallback onCancelTotp;
  final VoidCallback onRetry;
  final void Function(String id) onRemoveFactor;

  const SecurityMfaCard({
    super.key,
    required this.mfaLoading,
    required this.mfaError,
    required this.mfaNotEnabled,
    required this.factors,
    this.mfaEmptyHint,
    this.mfaMessage,
    required this.mfaOk,
    required this.mfaBusy,
    required this.totpPanelOpen,
    required this.pendingSecret,
    required this.pendingUri,
    required this.totpLabelCtrl,
    required this.totpCodeCtrl,
    required this.totpBusy,
    this.totpMsg,
    required this.onBeginTotp,
    required this.onConfirmTotp,
    required this.onCancelTotp,
    required this.onRetry,
    required this.onRemoveFactor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return PortalCard(
      title: 'Two-factor methods',
      children: [
        if (mfaLoading)
          const SkeletonListTile(itemCount: 2)
        else if (factors.isEmpty)
          _FactorStateHint(
            icon: mfaNotEnabled
                ? Icons.toggle_off_outlined
                : mfaError
                ? Icons.cloud_off_outlined
                : Icons.shield_outlined,
            color: mfaError
                ? AppColors.danger
                : mfaNotEnabled
                ? AppColors.muted
                : AppColors.success,
            text: mfaEmptyHint ?? 'No second factors registered.',
            onRetry: mfaError ? onRetry : null,
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StatusChip(
                label: context.tr('{count} factors registered', {
                  'count': factors.length,
                }),
                color: AppColors.success,
                icon: Icons.verified_user_outlined,
              ),
            ),
          ),
          for (final raw in factors)
            SecurityFactorTile(
              factor: raw as Map,
              busy: mfaBusy,
              onRemove: (id) => onRemoveFactor(id),
            ),
        ],
        MessageBanner(mfaMessage, ok: mfaOk),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: mfaBusy ? null : onBeginTotp,
          icon: const Icon(Icons.phone_android_outlined),
          label: Text(context.tr('Add authenticator app')),
        ),
        if (totpPanelOpen) ...[
          const Divider(height: 28),
          Text(
            context.tr(
              'Add this secret to your authenticator app, then enter the 6-digit code to confirm.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (pendingSecret.isNotEmpty) _SecretBox(secret: pendingSecret),
          if (pendingUri.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              pendingUri,
              style: TextStyle(color: accent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: totpLabelCtrl,
            decoration: InputDecoration(
              labelText: context.tr('Device name (optional)'),
              prefixIcon: const Icon(Icons.devices_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: totpCodeCtrl,
            decoration: InputDecoration(
              labelText: context.tr('6-digit code'),
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: totpBusy ? null : onConfirmTotp,
                  icon: totpBusy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(context.tr('Verify and save')),
                ),
                TextButton(
                  onPressed: totpBusy ? null : onCancelTotp,
                  child: Text(context.tr('Cancel and clear secret')),
                ),
              ],
            ),
          ),
          MessageBanner(totpMsg, ok: false),
        ],
      ],
    );
  }
}

/// Compact inline empty/error hint for the factor list: semantic icon +
/// color-coded text + optional retry. Deliberately shorter than the shared
/// [EmptyState] (which is sized for page-level layouts) so the TOTP
/// enrollment controls stay within the card viewport.
class _FactorStateHint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onRetry;

  const _FactorStateHint({
    required this.icon,
    required this.color,
    required this.text,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr(text),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(context.tr('Retry')),
            ),
        ],
      ),
    );
  }
}

/// One-time TOTP secret display: bordered mono box, copyable via
/// [SelectableText]. The secret is intentionally never retained in card
/// state — the caller clears it when the panel closes.
class _SecretBox extends StatelessWidget {
  final String secret;
  const _SecretBox({required this.secret});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: SelectableText(
        secret,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
