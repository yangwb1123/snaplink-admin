import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

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
          Text(
            'New break-glass request',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetController,
            decoration: const InputDecoration(
              labelText: 'Target user ID',
              hintText: 'user@example.com',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (ticket/incident ref)',
              hintText: 'INC-12345',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: scope,
            decoration: const InputDecoration(labelText: 'Scope'),
            items: const [
              DropdownMenuItem(value: 'readonly', child: Text('Read-only')),
              DropdownMenuItem(
                value: 'impersonate',
                child: Text('Impersonate'),
              ),
              DropdownMenuItem(value: 'escalate', child: Text('Escalate')),
            ],
            onChanged: (value) => onScopeChanged(value ?? 'readonly'),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              labelText: 'TTL (seconds, default 900)',
            ),
            onChanged: onTtlChanged,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require approval'),
            value: requireApproval,
            onChanged: (value) => onRequireApprovalChanged(value ?? false),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onCreate,
            child: mutating
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create break-glass request'),
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
          Text('Sessions', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      if (loading) const SkeletonListTile(itemCount: 3),
      if (!loading && sessions.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('No break-glass sessions.'),
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
        title: Text('$targetUser · $status'),
        subtitle: Text('$reason\nby $createdBy · scope: $scope · $id'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending)
              TextButton(
                onPressed: mutating ? null : () => onApprove(id),
                child: const Text('Approve'),
              ),
            if (active)
              TextButton(
                onPressed: mutating ? null : () => onImpersonate(id),
                child: const Text('Impersonate'),
              ),
            if (pending || active)
              TextButton(
                onPressed: mutating ? null : () => onRevoke(id),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Revoke'),
              ),
          ],
        ),
      ),
    );
  }
}
