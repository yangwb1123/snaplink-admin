import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_widgets.dart';
import 'security_factor_tile.dart';

/// MFA (Two-factor methods) card for the security tab.
class SecurityMfaCard extends StatelessWidget {
  final bool mfaLoading;
  final List factors;
  final String? mfaEmptyHint;
  final String? mfaMessage;
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
  final void Function(String id) onRemoveFactor;

  const SecurityMfaCard({
    super.key,
    required this.mfaLoading,
    required this.factors,
    this.mfaEmptyHint,
    this.mfaMessage,
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
    required this.onRemoveFactor,
  });

  @override
  Widget build(BuildContext context) => PortalCard(
    title: 'Two-factor methods',
    children: [
      if (mfaLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        )
      else if (factors.isEmpty)
        EmptyHint(mfaEmptyHint ?? 'No second factors registered.')
      else ...[
        // 因子计数徽章（安全状态可视化）。
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: StatusChip(
              label: '${factors.length} factors registered',
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
      MessageBanner(mfaMessage, ok: mfaMessage == 'Second factor removed.'),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: mfaBusy ? null : onBeginTotp,
        child: Text(context.tr('Add authenticator app')),
      ),
      if (totpPanelOpen) ...[
        const Divider(height: 28),
        Text(
          context.tr(
            'Add this secret to your authenticator app, then enter the 6-digit code to confirm.',
          ),
        ),
        const SizedBox(height: 8),
        if (pendingSecret.isNotEmpty) KvRow('Secret', pendingSecret),
        if (pendingUri.isNotEmpty)
          SelectableText(
            pendingUri,
            style: const TextStyle(color: AppColors.primary),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: totpLabelCtrl,
          decoration: InputDecoration(
            labelText: context.tr('Device name (optional)'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: totpCodeCtrl,
          decoration: InputDecoration(labelText: context.tr('6-digit code')),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: totpBusy ? null : onConfirmTotp,
                child: totpBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Verify and save')),
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
