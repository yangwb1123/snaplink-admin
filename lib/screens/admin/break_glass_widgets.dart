import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';

abstract final class BreakGlassRevocationCopy {
  static const confirmation =
      'Revoke this emergency-access grant? Snaplink will report every derived '
      'session and token result. Failed items retain stable idempotency keys '
      'for reconciliation.';

  static String result(Map<String, dynamic> response) {
    final values = response['credential_results'];
    final results = values is List
        ? values.whereType<Map>().toList()
        : const <Map>[];
    final failed = results.where((item) => item['status'] != 'revoked').length;
    final revoked = results.length - failed;
    if (response['retryable'] == true || failed > 0) {
      return 'Grant revoked; $revoked derived credentials were revoked and '
          '$failed failed. Retry only the reported idempotency keys.';
    }
    return 'Grant and all $revoked reported derived credentials were revoked.';
  }
}

class BreakGlassRequestCard extends StatelessWidget {
  final TextEditingController targetController;
  final TextEditingController reasonController;
  final String scope;
  final bool requireApproval;
  final bool mutating;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String> onTtlChanged;
  final ValueChanged<bool> onRequireApprovalChanged;
  final VoidCallback onCreate;

  const BreakGlassRequestCard({
    super.key,
    required this.targetController,
    required this.reasonController,
    required this.scope,
    required this.requireApproval,
    required this.mutating,
    required this.onScopeChanged,
    required this.onTtlChanged,
    required this.onRequireApprovalChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'New break-glass request',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetController,
            decoration: InputDecoration(
              labelText: 'Target user ID'.localized,
              hintText: 'user@example.com'.localized,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: 'Reason (ticket/incident ref)'.localized,
              hintText: 'INC-12345'.localized,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: scope,
            decoration: InputDecoration(labelText: 'Scope'.localized),
            items: const [
              DropdownMenuItem(
                value: 'readonly',
                child: LocalizedText('Read-only'),
              ),
              DropdownMenuItem(
                value: 'impersonate',
                child: LocalizedText('Impersonate'),
              ),
              DropdownMenuItem(
                value: 'escalate',
                child: LocalizedText('Escalate'),
              ),
            ],
            onChanged: (value) => onScopeChanged(value ?? 'readonly'),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'TTL (seconds, default 900)'.localized,
            ),
            onChanged: onTtlChanged,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const LocalizedText('Require approval'),
            value: requireApproval,
            onChanged: (value) => onRequireApprovalChanged(value ?? false),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onCreate,
            child: mutating
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const LocalizedText('Create break-glass request'),
          ),
        ],
      ),
    ),
  );
}

class BreakGlassSessionsList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final bool loading;
  final bool mutating;
  final VoidCallback onRefresh;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onImpersonate;
  final ValueChanged<String> onRevoke;

  const BreakGlassSessionsList({
    super.key,
    required this.sessions,
    required this.loading,
    required this.mutating,
    required this.onRefresh,
    required this.onOpen,
    required this.onApprove,
    required this.onImpersonate,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          LocalizedText(
            'Sessions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh'.localized,
          ),
        ],
      ),
      if (loading) const SkeletonListTile(itemCount: 3),
      if (!loading && sessions.isEmpty)
        EmptyState(title: 'No break-glass sessions.'),
      if (!loading && sessions.isNotEmpty)
        AdminDataTable(
          minWidth: 920,
          columns: [
            AdminDataColumn(
              id: 'session',
              label: 'Session',
              width: 220,
              cardPrimary: true,
              builder: (_, i) => LocalizedText(
                '{targetUser} · {status}',
                args: {
                  'targetUser': sessions[i]['target_user_id']?.toString() ??
                      sessions[i]['target_user']?.toString() ??
                      '',
                  'status': sessions[i]['status']?.toString() ?? 'unknown',
                },
              ),
            ),
            AdminDataColumn(
              id: 'status',
              label: 'Status',
              builder: (_, i) => _sessionStatusChip(
                sessions[i]['status']?.toString() ?? 'unknown',
              ),
            ),
            AdminDataColumn(
              id: 'details',
              label: 'Details',
              cardDetail: true,
              builder: (_, i) {
                final session = sessions[i];
                final id = session['id']?.toString() ?? '';
                final reason = session['reason']?.toString() ?? '';
                final createdBy = session['created_by']?.toString() ?? '';
                final scope = session['scope']?.toString() ?? 'readonly';
                return TableCellText(
                  [
                    if (reason.isNotEmpty) reason,
                    'by $createdBy · scope: $scope · $id',
                  ].join('\n'),
                  muted: true,
                  maxLines: 2,
                );
              },
            ),
            AdminDataColumn(
              id: 'actions',
              label: '',
              width: 360,
              builder: (_, i) {
                final id = sessions[i]['id']?.toString() ?? '';
                final status =
                    sessions[i]['status']?.toString() ?? 'unknown';
                final pending = status == 'pending';
                final active = status == 'active';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pending)
                      TextButton(
                        onPressed: mutating ? null : () => onApprove(id),
                        child: const LocalizedText('Approve'),
                      ),
                    if (active)
                      TextButton(
                        onPressed: mutating ? null : () => onImpersonate(id),
                        child: const LocalizedText('Impersonate'),
                      ),
                    if (pending || active)
                      TextButton(
                        onPressed: mutating ? null : () => onRevoke(id),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        child: const LocalizedText('Revoke'),
                      ),
                  ],
                );
              },
            ),
          ],
          itemCount: sessions.length,
          rowBuilder: (_, _) => const SizedBox.shrink(),
          onRowTap: (i) => onOpen(sessions[i]['id']?.toString() ?? ''),
        ),
    ],
  );

  StatusChip _sessionStatusChip(String status) => switch (status) {
    'pending' => StatusChip.pending(label: 'Pending'),
    'active' => StatusChip.active(label: 'Active'),
    'revoked' => StatusChip.inactive(label: 'Revoked'),
    'expired' => StatusChip.inactive(label: 'Expired'),
    _ => StatusChip.unknown(label: status),
  };
}
