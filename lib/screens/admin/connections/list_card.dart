import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

class ConnectionsListCard extends StatelessWidget {
  final TextEditingController tenantController;
  final TextEditingController lookupController;
  final List<Map<String, dynamic>> connections;
  final bool canList;
  final bool canGet;
  final bool loadingList;
  final bool loadingConnection;
  final bool mutating;
  final VoidCallback onLoadList;
  final VoidCallback onLoadSelected;
  final ValueChanged<String> onSelect;

  const ConnectionsListCard({
    super.key,
    required this.tenantController,
    required this.lookupController,
    required this.connections,
    required this.canList,
    required this.canGet,
    required this.loadingList,
    required this.loadingConnection,
    required this.mutating,
    required this.onLoadList,
    required this.onLoadSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'Tenant connections',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tenantController,
            decoration: InputDecoration(
              labelText: 'Tenant ID'.localized,
              hintText: 'acme'.localized,
            ),
            onSubmitted: (_) => onLoadList(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !canList || loadingList || mutating ? null : onLoadList,
            child: loadingList
                ? const LocalizedText('Loading…')
                : const LocalizedText('List connections'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lookupController,
            decoration: InputDecoration(
              labelText: 'Connection ID'.localized,
              hintText: 'acme-okta'.localized,
            ),
            onSubmitted: (_) => onLoadSelected(),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: !canGet || loadingConnection || mutating
                ? null
                : onLoadSelected,
            child: const LocalizedText('Get connection'),
          ),
          if (connections.isEmpty && !loadingList)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalizedText('No connections loaded.'),
            ),
          if (connections.isNotEmpty) _summaryBar(context),
          for (final connection in connections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                connection['enabled'] == false
                    ? Icons.link_off_outlined
                    : Icons.link_outlined,
              ),
              title: Text(_connectionTitle(connection)),
              subtitle: LocalizedText(
                '${connection['id'] ?? ''} · ${connection['type'] ?? ''}${connection['enabled'] == false ? ' · disabled' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: !canGet
                  ? null
                  : () => onSelect(connection['id']?.toString() ?? ''),
            ),
        ],
      ),
    ),
  );

  /// 连接健康摘要（异常优先：禁用连接占比一眼可见）。
  Widget _summaryBar(BuildContext context) {
    final total = connections.length;
    final disabled = connections
        .where((c) => c['enabled'] == false)
        .length;
    final disabledFraction = total == 0 ? 0.0 : disabled / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LocalizedText(
                'Connections health',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$disabled of $total disabled',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: disabledFraction > 0.3
                      ? AppColors.danger
                      : disabledFraction > 0.1
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: AppColors.success.withValues(alpha: 0.15),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: disabledFraction.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [AppColors.warning, AppColors.danger],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _connectionTitle(Map<String, dynamic> connection) {
    final displayName = connection['display_name']?.toString() ?? '';
    return displayName.isNotEmpty
        ? displayName
        : connection['id']?.toString() ?? 'Unnamed connection';
  }
}
