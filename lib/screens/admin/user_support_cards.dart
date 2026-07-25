import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

/// Session list card displayed in user support view.
class SessionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;

  const SessionsCard({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) => _card(context, 'Active sessions', [
    if (sessions.isEmpty)
      const Text('No active sessions.')
    else
      for (final session in sessions)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(session['id']?.toString() ?? ''),
          subtitle: Text(
            '${session['ip'] ?? ''} ${session['user_agent'] ?? ''}'
                .trim(),
          ),
        ),
  ]);
}

/// Application consents card.
class ConsentsCard extends StatelessWidget {
  final List<Map<String, dynamic>> consents;
  final String userId;
  final bool mutating;
  final Future<void> Function(String clientId) onRevoke;

  const ConsentsCard({
    super.key,
    required this.consents,
    required this.userId,
    required this.mutating,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => _card(context, 'Application consents', [
    if (consents.isEmpty) const Text('No grants found.'),
    for (final consent in consents)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(consent['client_id']?.toString() ?? ''),
        subtitle: Text((consent['scopes'] as List? ?? const []).join(' ')),
        trailing: TextButton(
          onPressed: mutating
              ? null
              : () async {
                  final confirmed = await ConfirmDialog.show(
                    context,
                    title: 'Revoke consent?',
                    message: 'Remove this application grant for $userId?',
                    confirmLabel: 'Revoke',
                    destructive: true,
                  );
                  if (confirmed) onRevoke(consent['client_id'].toString());
                },
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('Revoke'),
        ),
      ),
  ]);
}

/// MFA factors card.
class MfaFactorsCard extends StatelessWidget {
  final List<Map<String, dynamic>> factors;
  final bool mutating;
  final bool canResetRecoveryCodes;
  final Future<void> Function(String factorId) onRemove;
  final VoidCallback? onResetRecoveryCodes;

  const MfaFactorsCard({
    super.key,
    required this.factors,
    required this.mutating,
    required this.canResetRecoveryCodes,
    required this.onRemove,
    this.onResetRecoveryCodes,
  });

  @override
  Widget build(BuildContext context) => _card(context, 'Second factors', [
    if (factors.isEmpty) const Text('No registered factors.'),
    for (final factor in factors)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          factor['label']?.toString() ?? factor['method']?.toString() ?? '',
        ),
        subtitle: Text(factor['method']?.toString() ?? ''),
        trailing: TextButton(
          onPressed: mutating
              ? null
              : () async {
                  final confirmed = await ConfirmDialog.show(
                    context,
                    title: 'Remove second factor?',
                    message: 'The user will no longer be able to use this factor.',
                    confirmLabel: 'Remove',
                    destructive: true,
                  );
                  if (confirmed) onRemove(factor['id'].toString());
                },
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('Remove'),
        ),
      ),
    if (canResetRecoveryCodes)
      OutlinedButton(
        onPressed: mutating ? null : onResetRecoveryCodes,
        child: const Text('Reset recovery codes'),
      ),
  ]);
}

/// Account lifecycle state machine card.
class LifecycleCard extends StatefulWidget {
  final Map<String, dynamic> lifecycleData;
  final bool mutating;
  final String? nextState;
  final ValueChanged<String?> onStateChanged;
  final TextEditingController reasonController;
  final VoidCallback onApply;

  const LifecycleCard({
    super.key,
    required this.lifecycleData,
    required this.mutating,
    required this.nextState,
    required this.onStateChanged,
    required this.reasonController,
    required this.onApply,
  });

  @override
  State<LifecycleCard> createState() => _LifecycleCardState();
}

class _LifecycleCardState extends State<LifecycleCard> {
  @override
  Widget build(BuildContext context) {
    final allowed = (widget.lifecycleData['allowed_transitions'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    return _card(context, 'Account lifecycle', [
      Text('Current state: ${widget.lifecycleData['state'] ?? 'active'}'),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: allowed.contains(widget.nextState) ? widget.nextState : null,
        decoration: const InputDecoration(labelText: 'Transition to'),
        items: allowed
            .map((state) => DropdownMenuItem(value: state, child: Text(state)))
            .toList(growable: false),
        onChanged: widget.mutating ? null : widget.onStateChanged,
      ),
      const SizedBox(height: 10),
      TextField(
        controller: widget.reasonController,
        decoration: const InputDecoration(labelText: 'Reason / ticket reference'),
      ),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: widget.mutating || widget.nextState == null ? null : widget.onApply,
        child: const Text('Apply transition'),
      ),
    ]);
  }
}

/// Credential recovery and containment actions card.
class CredentialRecoveryCard extends StatelessWidget {
  final Map<String, dynamic>? passwordResetData;
  final Map<String, dynamic>? emailChangeData;
  final bool mutating;
  final bool canSetPassword;
  final bool canSetEmail;
  final TextEditingController passwordController;
  final TextEditingController emailController;
  final VoidCallback? onSetPassword;
  final VoidCallback? onSetEmail;
  final List<DangerAction> dangerActions;

  const CredentialRecoveryCard({
    super.key,
    this.passwordResetData,
    this.emailChangeData,
    required this.mutating,
    required this.canSetPassword,
    required this.canSetEmail,
    required this.passwordController,
    required this.emailController,
    this.onSetPassword,
    this.onSetEmail,
    required this.dangerActions,
  });

  @override
  Widget build(BuildContext context) => _card(
    context,
    'Credential recovery and containment',
    [
      if (passwordResetData != null)
        _recoveryStatus('Active password-reset links', passwordResetData!),
      if (emailChangeData != null)
        _recoveryStatus('Active email-change links', emailChangeData!),
      if (canSetPassword) ...[
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: mutating || passwordController.text.isEmpty ? null : onSetPassword,
          child: const Text('Set password'),
        ),
      ],
      if (canSetEmail) ...[
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Replacement email'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: mutating || emailController.text.trim().isEmpty ? null : onSetEmail,
          child: const Text('Set email'),
        ),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: dangerActions.map((a) => a.build(context)).toList(),
      ),
    ],
  );

  Widget _recoveryStatus(String label, Map<String, dynamic> data) {
    final records = data['tokens'] ?? data['links'] ?? data['items'];
    final count = data['total'] ?? data['count'] ?? (records is List ? records.length : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('$label: $count'),
    );
  }
}

/// A danger action that requires confirmation.
class DangerAction {
  final String label;
  final String confirmTitle;
  final String confirmMessage;
  final VoidCallback onConfirmed;

  const DangerAction({
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onConfirmed,
  });

  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final confirmed = await ConfirmDialog.show(
          context,
          title: confirmTitle,
          message: confirmMessage,
          confirmLabel: label,
          destructive: true,
        );
        if (confirmed) onConfirmed();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
      ),
      child: Text(label),
    );
  }
}

// Shared card wrapper
Widget _card(BuildContext context, String title, List<Widget> children) => Card(
  margin: const EdgeInsets.only(top: 20),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  ),
);
