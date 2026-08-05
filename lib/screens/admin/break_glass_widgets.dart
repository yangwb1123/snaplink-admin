import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

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
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LocalizedText('No break-glass sessions.'),
        ),
      if (!loading)
        for (final session in sessions)
          _BreakGlassSessionCard(
            session: session,
            mutating: mutating,
            onOpen: onOpen,
            onApprove: onApprove,
            onImpersonate: onImpersonate,
            onRevoke: onRevoke,
          ),
    ],
  );
}

class _BreakGlassSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool mutating;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onImpersonate;
  final ValueChanged<String> onRevoke;

  const _BreakGlassSessionCard({
    required this.session,
    required this.mutating,
    required this.onOpen,
    required this.onApprove,
    required this.onImpersonate,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final id = session['id']?.toString() ?? '';
    final targetUser =
        session['target_user_id']?.toString() ??
        session['target_user']?.toString() ??
        '';
    final status = session['status']?.toString() ?? 'unknown';
    final reason = session['reason']?.toString() ?? '';
    final createdBy = session['created_by']?.toString() ?? '';
    final scope = session['scope']?.toString() ?? 'readonly';
    final pending = status == 'pending';
    final active = status == 'active';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        onTap: () => onOpen(id),
        leading: Icon(
          pending
              ? Icons.hourglass_empty
              : active
              ? Icons.flash_on
              : Icons.cancel,
          color: pending
              ? Colors.orange
              : active
              ? Colors.green
              : Colors.grey,
        ),
        title: LocalizedText('$targetUser · $status'),
        subtitle: LocalizedText('$reason\nby $createdBy · scope: $scope · $id'),
        isThreeLine: true,
        trailing: Row(
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
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const LocalizedText('Revoke'),
              ),
          ],
        ),
      ),
    );
  }
}
