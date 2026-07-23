import 'package:flutter/material.dart';

import 'snaplink_admin_api.dart';

/// Landing page for the Snaplink operator console.
///
/// Snaplink deliberately makes many admin routes optional. Showing this live
/// inventory before rendering optional management areas prevents a console
/// built for a full deployment from offering a control that this replica has
/// not registered.
class AdminOverviewTab extends StatelessWidget {
  final List<SnaplinkAdminEndpoint> endpoints;
  final Object? loadError;
  final VoidCallback onRefresh;

  const AdminOverviewTab({
    super.key,
    required this.endpoints,
    required this.loadError,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final capabilities = SnaplinkAdminCapabilities(endpoints);
    final groups = _groupEndpoints(endpoints);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Platform overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh capabilities',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loadError != null)
          _StatusCard(
            icon: Icons.cloud_off,
            title: 'Capability inventory is unavailable',
            body: '$loadError',
            color: Colors.orange,
          )
        else if (endpoints.isEmpty)
          const _StatusCard(
            icon: Icons.hourglass_empty,
            title: 'Loading runtime capabilities',
            body:
                'The navigation will expand only for routes registered by this Snaplink replica.',
            color: Colors.blue,
          )
        else ...[
          _StatusCard(
            icon: Icons.verified_user_outlined,
            title: '${endpoints.length} management endpoints available',
            body:
                '${capabilities.featureCounts.length} feature surfaces are active on this replica.',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'Enabled feature surfaces',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: capabilities.featureCounts.entries
                .map(
                  (entry) => Chip(label: Text('${entry.key} · ${entry.value}')),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 20),
          Text(
            'Available management domains',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final entry in groups.entries)
            Card(
              child: ExpansionTile(
                leading: Icon(entry.value.icon),
                title: Text(entry.key),
                subtitle: Text(
                  '${entry.value.endpoints.length} live endpoints',
                ),
                children: [
                  for (final endpoint in entry.value.endpoints)
                    ListTile(
                      dense: true,
                      title: Text(
                        endpoint.path,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(endpoint.method),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Map<String, _EndpointGroup> _groupEndpoints(
    List<SnaplinkAdminEndpoint> endpoints,
  ) {
    final groups = <String, _EndpointGroup>{};
    for (final endpoint in endpoints) {
      final group = _groupFor(endpoint.path);
      groups
          .putIfAbsent(group.$1, () => _EndpointGroup(group.$2))
          .endpoints
          .add(endpoint);
    }
    return groups;
  }

  (String, IconData) _groupFor(String path) {
    if (path.contains('/clients') || path.contains('/register')) {
      return ('Applications and OAuth', Icons.apps_outlined);
    }
    if (path.contains('/users') ||
        path.contains('/local-users') ||
        path.contains('/connections')) {
      return ('Identity and connections', Icons.people_outline);
    }
    if (path.contains('/tenants') || path.contains('/domains')) {
      return ('Tenants and organizations', Icons.business_outlined);
    }
    if (path.contains('/tokens') ||
        path.contains('/sessions') ||
        path.contains('/logout')) {
      return ('Tokens and sessions', Icons.security_outlined);
    }
    if (path.contains('/keys') ||
        path.contains('/credentials') ||
        path.contains('/break-glass')) {
      return ('Security operations', Icons.key_outlined);
    }
    if (path.contains('/compliance') ||
        path.contains('/changes') ||
        path.contains('/audit') ||
        path.contains('/policy')) {
      return ('Governance and compliance', Icons.gavel_outlined);
    }
    if (path.contains('/snapshots') ||
        path.contains('/releases') ||
        path.contains('/backup') ||
        path.contains('/dr/') ||
        path.contains('/health') ||
        path.contains('/config')) {
      return ('Platform operations', Icons.monitor_heart_outlined);
    }
    return ('Other exposed APIs', Icons.extension_outlined);
  }
}

class _EndpointGroup {
  final IconData icon;
  final List<SnaplinkAdminEndpoint> endpoints = [];

  _EndpointGroup(this.icon);
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(body),
    ),
  );
}
