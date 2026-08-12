import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
export 'account_lockout_card.dart';
/// Session list card displayed in user support view.
class SessionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  const SessionsCard({super.key, required this.sessions});
  @override
  Widget build(BuildContext context) => _card(
    context,
    'Active sessions',
    [
      if (sessions.isEmpty)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No active sessions.',
          compact: true,
        )
      else
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 460,
          columns: [
            AdminDataColumn(
              id: 'session',
              label: 'SESSION',
              width: 220,
              cardPrimary: true,
              builder: (context, i) => TableCellText(
                sessions[i]['id']?.toString() ?? '',
                bold: true,
              ),
            ),
            AdminDataColumn(
              id: 'device',
              label: 'DEVICE',
              width: 320,
              builder: (context, i) => TableCellText(
                '${sessions[i]['ip'] ?? ''} ${sessions[i]['user_agent'] ?? ''}'
                    .trim(),
                muted: true,
              ),
            ),
          ],
          itemCount: sessions.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
    ],
    count: sessions.length,
  );
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
  Widget build(BuildContext context) => _card(
    context,
    'Application consents',
    [
      if (consents.isEmpty)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No grants found.',
          compact: true,
        )
      else
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 520,
          columns: [
            AdminDataColumn(
              id: 'client',
              label: 'CLIENT',
              width: 220,
              cardPrimary: true,
              builder: (context, i) => TableCellText(
                consents[i]['client_id']?.toString() ?? '',
                bold: true,
              ),
            ),
            AdminDataColumn(
              id: 'scopes',
              label: 'SCOPES',
              width: 240,
              builder: (context, i) => TableCellText(
                (consents[i]['scopes'] as List? ?? const []).join(' '),
                muted: true,
              ),
            ),
            AdminDataColumn(
              id: 'actions',
              label: '',
              width: 100,
              builder: (context, i) => TextButton(
                onPressed: mutating
                    ? null
                    : () => onRevoke(
                        consents[i]['client_id']?.toString() ?? '',
                      ),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const LocalizedText('Revoke'),
              ),
            ),
          ],
          itemCount: consents.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
    ],
    count: consents.length,
  );
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
  Widget build(BuildContext context) => _card(
    context,
    'Second factors',
    [
      if (factors.isEmpty)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No registered factors.',
          compact: true,
        )
      else
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 460,
          columns: [
            AdminDataColumn(
              id: 'factor',
              label: 'FACTOR',
              width: 220,
              cardPrimary: true,
              builder: (context, i) => TableCellText(
                factors[i]['label']?.toString() ??
                    factors[i]['method']?.toString() ??
                    '',
                bold: true,
              ),
            ),
            AdminDataColumn(
              id: 'method',
              label: 'METHOD',
              width: 140,
              builder: (context, i) => TableCellText(
                factors[i]['method']?.toString() ?? '',
                muted: true,
              ),
            ),
            AdminDataColumn(
              id: 'actions',
              label: '',
              width: 110,
              builder: (context, i) => TextButton(
                onPressed: mutating
                    ? null
                    : () => onRemove(factors[i]['id']?.toString() ?? ''),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const LocalizedText('Remove'),
              ),
            ),
          ],
          itemCount: factors.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
      if (canResetRecoveryCodes)
        OutlinedButton(
          onPressed: mutating ? null : onResetRecoveryCodes,
          child: const LocalizedText('Reset recovery codes'),
        ),
    ],
    count: factors.length,
  );
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
    final allowed =
        (widget.lifecycleData['allowed_transitions'] as List? ?? const [])
            .map((value) => value.toString())
            .toList();
    return _card(context, 'Account lifecycle', [
      LocalizedText(
        'Current state: {state}',
        args: {'state': widget.lifecycleData['state'] ?? 'active'},
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: allowed.contains(widget.nextState)
            ? widget.nextState
            : null,
        decoration: InputDecoration(labelText: 'Transition to'.localized),
        items: allowed
            .map(
              (state) => DropdownMenuItem(value: state, child: Text(state)),
            )
            .toList(growable: false),
        onChanged: widget.mutating ? null : widget.onStateChanged,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: widget.reasonController,
        decoration: InputDecoration(
          labelText: 'Reason / ticket reference'.localized,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: widget.mutating || widget.nextState == null
            ? null
            : widget.onApply,
        child: const LocalizedText('Apply transition'),
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
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: 'New password'.localized),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: mutating || passwordController.text.isEmpty
              ? null
              : onSetPassword,
          child: const LocalizedText('Set password'),
        ),
      ],
      if (canSetEmail) ...[
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'Replacement email'.localized),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: mutating || emailController.text.trim().isEmpty
              ? null
              : onSetEmail,
          child: const LocalizedText('Set email'),
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
    final count =
        data['total'] ??
        data['count'] ??
        (records is List ? records.length : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LocalizedText(
        '{label}: {count}',
        args: {'label': label, 'count': count},
      ),
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
      onPressed: onConfirmed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      ),
      child: LocalizedText(label),
    );
  }
}
// Shared card wrapper: SectionHeader 标题行（含 count 徽章）+ 内容区。
Widget _card(
  BuildContext context,
  String title,
  List<Widget> children, {
  int? count,
}) => Card(
  margin: const EdgeInsets.only(top: 20),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, count: count),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  ),
);