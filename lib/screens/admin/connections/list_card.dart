import 'package:flutter/material.dart';
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

  String _connectionTitle(Map<String, dynamic> connection) {
    final displayName = connection['display_name']?.toString() ?? '';
    return displayName.isNotEmpty
        ? displayName
        : connection['id']?.toString() ?? 'Unnamed connection';
  }
}
