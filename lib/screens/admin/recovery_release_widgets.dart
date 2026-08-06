import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

List<Map<String, dynamic>> recoveryRecords(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const [];

Map<String, dynamic>? recoveryRecord(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

class RecoveryStatusCard extends StatelessWidget {
  final Map<String, dynamic> status;

  const RecoveryStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.health_and_safety_outlined),
      title: const LocalizedText('Disaster-recovery readiness'),
      subtitle: Text(
        status.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' · '),
      ),
    ),
  );
}

class RecoveryOperationsCard extends StatelessWidget {
  final List<Map<String, dynamic>> operations;

  const RecoveryOperationsCard({super.key, required this.operations});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Durable operation journal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const LocalizedText(
            'Restore, pin, and rollback steps remain queryable after a client disconnect or server restart.',
          ),
          if (operations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalizedText('No recovery or release operations.'),
            ),
          for (final operation in operations)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Icon(
                operation['state'] == 'succeeded'
                    ? Icons.task_alt
                    : operation['state'] == 'failed'
                    ? Icons.error_outline
                    : Icons.pending_outlined,
              ),
              title: Text(operation['id']?.toString() ?? ''),
              subtitle: Text(
                '${operation['kind'] ?? ''} · ${operation['target'] ?? ''} · '
                '${operation['state'] ?? ''}',
              ),
              children: [
                for (final step in recoveryRecords(operation['steps']))
                  _OperationStepTile(label: 'Step', step: step),
                for (final step in recoveryRecords(operation['compensations']))
                  _OperationStepTile(label: 'Compensation', step: step),
                if (operation['error']?.toString().isNotEmpty == true)
                  ListTile(
                    dense: true,
                    title: const LocalizedText('Operation error'),
                    subtitle: SelectableText(operation['error'].toString()),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _OperationStepTile extends StatelessWidget {
  final String label;
  final Map<String, dynamic> step;

  const _OperationStepTile({required this.label, required this.step});

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text('$label · ${step['name'] ?? ''} · ${step['state'] ?? ''}'),
    subtitle: step['error']?.toString().isNotEmpty == true
        ? SelectableText(step['error'].toString())
        : null,
  );
}

String releaseSummary(Map<String, dynamic> release) =>
    '${release['channel'] ?? ''} · schema ${release['schema_version'] ?? 0}'
    '${release['config_snapshot']?.toString().isNotEmpty == true ? ' · snapshot ${release['config_snapshot']}' : ''}';

class RecoverySnapshotsCard extends StatelessWidget {
  final List<Map<String, dynamic>> snapshots;
  final bool canCreate;
  final bool mutating;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onRestore;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const RecoverySnapshotsCard({
    super.key,
    required this.snapshots,
    required this.canCreate,
    required this.mutating,
    required this.onCreate,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LocalizedText(
                'Snapshots',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (canCreate)
                FilledButton.icon(
                  onPressed: mutating ? null : onCreate,
                  icon: const Icon(Icons.camera_outlined),
                  label: const LocalizedText('Export snapshot'),
                ),
            ],
          ),
          if (snapshots.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalizedText('No stored snapshots.'),
            ),
          for (final snapshot in snapshots)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(snapshot['snapshot_id']?.toString() ?? ''),
              subtitle: LocalizedText(
                '${snapshot['codec'] ?? ''} · ${snapshot['size_bytes'] ?? 0} '
                'bytes · schema ${snapshot['schema_version'] ?? ''}',
              ),
              trailing: PopupMenuButton<String>(
                enabled: !mutating,
                onSelected: (action) => action == 'restore'
                    ? onRestore(snapshot)
                    : onDelete(snapshot),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'restore',
                    child: LocalizedText('Restore'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: LocalizedText('Delete'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class RecoveryReleasesCard extends StatelessWidget {
  final List<Map<String, dynamic>> releases;
  final Map<String, dynamic>? current;
  final bool canRegister;
  final bool mutating;
  final VoidCallback onRegister;
  final void Function(Map<String, dynamic>, String) onAction;

  const RecoveryReleasesCard({
    super.key,
    required this.releases,
    required this.current,
    required this.canRegister,
    required this.mutating,
    required this.onRegister,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LocalizedText(
                'Paired releases',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (canRegister)
                FilledButton.icon(
                  onPressed: mutating ? null : onRegister,
                  icon: const Icon(Icons.add),
                  label: const LocalizedText('Register release'),
                ),
            ],
          ),
          if (current != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.push_pin, color: AppColors.success),
              title: LocalizedText('Current: ${current!['id'] ?? ''}'),
              subtitle: Text(releaseSummary(current!)),
            ),
          if (releases.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalizedText('No registered releases.'),
            ),
          for (final release in releases)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(release['id']?.toString() ?? ''),
              subtitle: Text(releaseSummary(release)),
              trailing: PopupMenuButton<String>(
                enabled: !mutating,
                onSelected: (action) => onAction(release, action),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pin', child: LocalizedText('Pin')),
                  PopupMenuItem(
                    value: 'rollback',
                    child: LocalizedText('Rollback'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: LocalizedText('Delete'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
