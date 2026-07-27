import 'package:flutter/material.dart';
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
      else
        for (final raw in factors)
          SecurityFactorTile(
            factor: raw as Map,
            busy: mfaBusy,
            onRemove: (id) => onRemoveFactor(id),
          ),
      MessageBanner(mfaMessage, ok: mfaMessage == 'Second factor removed.'),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: mfaBusy ? null : onBeginTotp,
        child: const Text('Add authenticator app'),
      ),
      if (totpPanelOpen) ...[
        const Divider(height: 28),
        const Text(
          'Add this secret to your authenticator app, then enter the 6-digit code to confirm.',
        ),
        const SizedBox(height: 8),
        if (pendingSecret.isNotEmpty) KvRow('Secret', pendingSecret),
        if (pendingUri.isNotEmpty)
          SelectableText(
            pendingUri,
            style: const TextStyle(color: Color(0xFF6366F1)),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: totpLabelCtrl,
          decoration: const InputDecoration(
            labelText: 'Device name (optional)',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: totpCodeCtrl,
          decoration: const InputDecoration(labelText: '6-digit code'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
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
                    : const Text('Verify and save'),
              ),
              TextButton(
                onPressed: totpBusy ? null : onCancelTotp,
                child: const Text('Cancel and clear secret'),
              ),
            ],
          ),
        ),
        MessageBanner(totpMsg, ok: false),
      ],
    ],
  );
}
