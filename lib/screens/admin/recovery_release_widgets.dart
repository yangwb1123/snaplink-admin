import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';

List<Map<String, dynamic>> recoveryRecords(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const [];

Map<String, dynamic>? recoveryRecord(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String releaseSummary(Map<String, dynamic> release) =>
    '${release['channel'] ?? ''} · schema ${release['schema_version'] ?? 0}'
    '${release['config_snapshot']?.toString().isNotEmpty == true ? ' · snapshot ${release['config_snapshot']}' : ''}';

/// DR readiness summary — a single-record status card (not a list), with the
/// module accent icon (X7) and copyable server key/value pairs.
class RecoveryStatusCard extends StatelessWidget {
  final Map<String, dynamic> status;

  const RecoveryStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: adminModuleIconColor('recovery-releases'),
              ),
              const SizedBox(width: 8),
              LocalizedText(
                'Disaster-recovery readiness',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            status.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join(' · '),
          ),
        ],
      ),
    ),
  );
}

/// Durable operation journal — a hierarchical drill-down (operation → steps →
/// compensations), so disclosure tiles are the right primitive for the
/// hierarchy; each operation's state is double-encoded via leading icon and a
/// trailing [StatusChip] (X9). Server values always render as [Text] (X1).
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
          SectionHeader('Durable operation journal', count: operations.length),
          const SizedBox(height: 4),
          const LocalizedText(
            'Restore, pin, and rollback steps remain queryable after a client disconnect or server restart.',
          ),
          if (operations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: EmptyState(
                variant: EmptyStateVariant.empty,
                title: 'No recovery or release operations.',
                compact: true,
              ),
            ),
          for (final operation in operations)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: _operationIcon(operation),
              title: Text(operation['id']?.toString() ?? ''),
              subtitle: Text(
                '${operation['kind'] ?? ''} · ${operation['target'] ?? ''}',
              ),
              trailing: _operationChip(operation['state']?.toString() ?? ''),
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

Widget _operationIcon(Map<String, dynamic> operation) {
  final state = operation['state']?.toString();
  return Icon(
    state == 'succeeded'
        ? Icons.task_alt
        : state == 'failed'
        ? Icons.error_outline
        : Icons.pending_outlined,
    color: state == 'succeeded'
        ? AppColors.success
        : state == 'failed'
        ? AppColors.danger
        : AppColors.warning,
  );
}

Widget _operationChip(String state) => switch (state) {
  'succeeded' => StatusChip(
    label: state,
    color: AppColors.success,
    icon: Icons.check_circle_outline,
  ),
  'failed' => StatusChip(
    label: state,
    color: AppColors.danger,
    icon: Icons.error_outline,
  ),
  _ => StatusChip(
    label: state,
    color: AppColors.warning,
    icon: Icons.pending_outlined,
  ),
};

/// One journal step/compensation row. Title is interpolated server data, so
/// it renders as [Text] — never as an i18n key (X1).
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

/// Stored snapshots — flat list of records, rendered as a compact
/// [AdminDataTable] (X6) with per-row restore/delete actions.
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
          SectionHeader(
            'Snapshots',
            count: snapshots.length,
            action: canCreate
                ? FilledButton.icon(
                    onPressed: mutating ? null : onCreate,
                    icon: const Icon(Icons.camera_outlined),
                    label: const LocalizedText('Export snapshot'),
                  )
                : null,
          ),
          if (snapshots.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: EmptyState(
                variant: EmptyStateVariant.empty,
                title: 'No stored snapshots.',
                compact: true,
              ),
            ),
          if (snapshots.isNotEmpty)
            AdminDataTable(
              density: TableDensity.compact,
              minWidth: 560,
              columns: [
                AdminDataColumn(
                  id: 'snapshot',
                  label: 'SNAPSHOT',
                  width: 200,
                  cardPrimary: true,
                  builder: (context, i) => TableCellText(
                    snapshots[i]['snapshot_id']?.toString() ?? '',
                    bold: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'details',
                  label: 'DETAILS',
                  width: 260,
                  builder: (context, i) => TableCellText(
                    '${snapshots[i]['codec'] ?? ''} · '
                    '${snapshots[i]['size_bytes'] ?? 0} bytes · schema '
                    '${snapshots[i]['schema_version'] ?? ''}',
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'actions',
                  label: '',
                  width: 100,
                  builder: (context, i) => PopupMenuButton<String>(
                    enabled: !mutating,
                    onSelected: (action) => action == 'restore'
                        ? onRestore(snapshots[i])
                        : onDelete(snapshots[i]),
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
              itemCount: snapshots.length,
              rowBuilder: (context, i) => const SizedBox.shrink(),
            ),
        ],
      ),
    ),
  );
}

/// Paired releases — compact [AdminDataTable] (X6) with the pinned current
/// release shown above, and per-row pin/rollback/delete actions.
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
          SectionHeader(
            'Paired releases',
            count: releases.length,
            action: canRegister
                ? FilledButton.icon(
                    onPressed: mutating ? null : onRegister,
                    icon: const Icon(Icons.add),
                    label: const LocalizedText('Register release'),
                  )
                : null,
          ),
          if (current != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.push_pin, color: AppColors.success),
              title: LocalizedText(
                'Current: {id}',
                args: {'id': current!['id'] ?? ''},
              ),
              subtitle: Text(releaseSummary(current!)),
            ),
          if (releases.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: EmptyState(
                variant: EmptyStateVariant.empty,
                title: 'No registered releases.',
                compact: true,
              ),
            ),
          if (releases.isNotEmpty)
            AdminDataTable(
              density: TableDensity.compact,
              minWidth: 560,
              columns: [
                AdminDataColumn(
                  id: 'release',
                  label: 'RELEASE',
                  width: 200,
                  cardPrimary: true,
                  builder: (context, i) => TableCellText(
                    releases[i]['id']?.toString() ?? '',
                    bold: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'summary',
                  label: 'SUMMARY',
                  width: 300,
                  builder: (context, i) => TableCellText(
                    releaseSummary(releases[i]),
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'actions',
                  label: '',
                  width: 100,
                  builder: (context, i) => PopupMenuButton<String>(
                    enabled: !mutating,
                    onSelected: (action) => onAction(releases[i], action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'pin',
                        child: LocalizedText('Pin'),
                      ),
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
              itemCount: releases.length,
              rowBuilder: (context, i) => const SizedBox.shrink(),
            ),
        ],
      ),
    ),
  );
}
