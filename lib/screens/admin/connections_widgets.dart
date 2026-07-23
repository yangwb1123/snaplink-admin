import 'dart:convert';

import 'package:flutter/material.dart';

class ConnectionErrorCard extends StatelessWidget {
  final String error;

  const ConnectionErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        error,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    ),
  );
}

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
          Text(
            'Tenant connections',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tenantController,
            decoration: const InputDecoration(
              labelText: 'Tenant ID',
              hintText: 'acme',
            ),
            onSubmitted: (_) => onLoadList(),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: !canList || loadingList || mutating ? null : onLoadList,
            child: Text(loadingList ? 'Loading…' : 'List connections'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lookupController,
            decoration: const InputDecoration(
              labelText: 'Connection ID',
              hintText: 'acme-okta',
            ),
            onSubmitted: (_) => onLoadSelected(),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: !canGet || loadingConnection || mutating
                ? null
                : onLoadSelected,
            child: const Text('Get connection'),
          ),
          if (connections.isEmpty && !loadingList)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No connections loaded.'),
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
              subtitle: Text(
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

class ConnectionCreateCard extends StatelessWidget {
  final TextEditingController idController;
  final TextEditingController tenantController;
  final TextEditingController displayNameController;
  final TextEditingController domainsController;
  final TextEditingController configController;
  final String type;
  final bool enabled;
  final bool mutating;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onSave;

  const ConnectionCreateCard({
    super.key,
    required this.idController,
    required this.tenantController,
    required this.displayNameController,
    required this.domainsController,
    required this.configController,
    required this.type,
    required this.enabled,
    required this.mutating,
    required this.onTypeChanged,
    required this.onEnabledChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create or replace connection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Saving an existing ID replaces its configuration and domain routing.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: idController,
            decoration: const InputDecoration(labelText: 'Connection ID'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: tenantController,
            decoration: const InputDecoration(labelText: 'Tenant ID'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Protocol'),
            items: const [
              DropdownMenuItem(value: 'oidc', child: Text('OIDC')),
              DropdownMenuItem(value: 'saml', child: Text('SAML')),
            ],
            onChanged: mutating
                ? null
                : (value) => onTypeChanged(value ?? type),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: displayNameController,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: domainsController,
            decoration: const InputDecoration(
              labelText: 'Email domains',
              hintText: 'example.com, subsidiary.example.com',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Connection enabled'),
            value: enabled,
            onChanged: mutating ? null : onEnabledChanged,
          ),
          TextField(
            controller: configController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Protocol configuration (JSON)',
              hintText: '{"oidc_issuer":"https://idp.example.com"}',
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: mutating ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save connection'),
          ),
        ],
      ),
    ),
  );
}

class ConnectionDetailsCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic>? connection;
  final Map<String, dynamic>? health;
  final List<Map<String, dynamic>> domainClaims;
  final bool loading;
  final bool mutating;
  final bool canProbe;
  final bool canListDomains;
  final bool canVerifyDomain;
  final bool canDelete;
  final VoidCallback onRefresh;
  final VoidCallback onProbe;
  final VoidCallback onDelete;
  final ValueChanged<String> onVerifyDomain;

  const ConnectionDetailsCard({
    super.key,
    required this.id,
    required this.connection,
    required this.health,
    required this.domainClaims,
    required this.loading,
    required this.mutating,
    required this.canProbe,
    required this.canListDomains,
    required this.canVerifyDomain,
    required this.canDelete,
    required this.onRefresh,
    required this.onProbe,
    required this.onDelete,
    required this.onVerifyDomain,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Connection: $id',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: loading || mutating ? null : onRefresh,
                tooltip: 'Refresh connection',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (connection != null) _summary(context),
            if (health != null) _healthCard(context),
            if (canProbe) _probeCard(),
            if (canListDomains) _domainsCard(context),
            if (canDelete)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: mutating ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete connection'),
                ),
              ),
          ],
        ],
      ),
    ),
  );

  Widget _summary(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${connection!['display_name'] ?? connection!['id']} · ${connection!['type'] ?? ''}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          connection!['enabled'] == false ? 'Disabled' : 'Enabled',
          style: TextStyle(
            color: connection!['enabled'] == false
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        if (connection!['config'] is Map)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(connection!['config']),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    ),
  );

  Widget _healthCard(BuildContext context) {
    final status = health!['status']?.toString() ?? 'unknown';
    final color = switch (status) {
      'healthy' => Colors.green,
      'degraded' => Colors.orange,
      'unreachable' => Colors.red,
      _ => Colors.blueGrey,
    };
    final checked = health!['last_checked_at']?.toString();
    final success = health!['last_success_at']?.toString();
    final error = health!['last_error']?.toString();
    final detail = [
      'Connection $id',
      if (checked != null && checked.isNotEmpty) 'checked $checked',
      if (success != null && success.isNotEmpty) 'last healthy $success',
      if (error != null && error.isNotEmpty) error,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: ListTile(
        leading: Icon(Icons.monitor_heart_outlined, color: color),
        title: Text('Upstream health: $status'),
        subtitle: Text(detail),
      ),
    );
  }

  Widget _probeCard() => Card(
    margin: const EdgeInsets.only(top: 16),
    child: ListTile(
      leading: const Icon(Icons.network_ping_outlined),
      title: const Text('Reachability probe'),
      subtitle: const Text(
        'Fetches the OIDC discovery document or SAML metadata and records the result.',
      ),
      trailing: FilledButton(
        onPressed: mutating ? null : onProbe,
        child: const Text('Probe'),
      ),
    ),
  );

  Widget _domainsCard(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Domain ownership',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Publish each DNS TXT record and then verify it. The challenge value is public DNS data, not a bearer secret.',
          ),
          if (domainClaims.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No domain claims found.'),
            ),
          for (final claim in domainClaims)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                claim['status'] == 'verified'
                    ? Icons.verified_outlined
                    : Icons.pending_outlined,
                color: claim['status'] == 'verified'
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(claim['domain']?.toString() ?? ''),
              subtitle: SelectableText(
                '${claim['status'] ?? 'pending'}\nTXT ${claim['record'] ?? ''}\n${claim['token'] ?? ''}',
              ),
              trailing: canVerifyDomain && claim['status'] != 'verified'
                  ? TextButton(
                      onPressed: mutating
                          ? null
                          : () => onVerifyDomain(
                              claim['domain']?.toString() ?? '',
                            ),
                      child: const Text('Verify'),
                    )
                  : null,
            ),
        ],
      ),
    ),
  );
}
