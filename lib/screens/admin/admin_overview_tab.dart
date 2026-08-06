import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';

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
    final documentedOnly = SnaplinkAdminOperationCatalog.endpoints
        .where((endpoint) => !capabilities.has(endpoint.method, endpoint.path))
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              AppStrings.of(context).platformOverview,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh capabilities'.localized,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loadError != null)
          _StatusCard(
            icon: Icons.cloud_off,
            title: 'Capability inventory is unavailable',
            body:
                'The console is using its versioned OpenAPI catalog and will '
                'probe optional pages safely. Runtime error: $loadError',
            color: AppColors.warning,
          )
        else if (endpoints.isEmpty)
          const _StatusCard(
            icon: Icons.hourglass_empty,
            title: 'Loading runtime capabilities',
            body:
                'Contract-backed modules remain discoverable while this replica is queried.',
            color: AppColors.accentBlue,
          )
        else ...[
          _StatusCard(
            icon: documentedOnly == 0
                ? Icons.verified_user_outlined
                : Icons.info_outline,
            title:
                '${endpoints.length} runtime endpoints advertised'
                '${documentedOnly == 0 ? '' : ' · $documentedOnly documented routes not advertised'}',
            body:
                'Runtime inventory proves deployment availability. OpenAPI-only '
                'modules stay visible for compatibility and report 404/501 as not enabled.',
            color: documentedOnly == 0 ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(height: 16),
          LocalizedText(
            'Enabled feature surfaces',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: capabilities.featureCounts.entries
                .map(
                  (entry) => Chip(
                    label: Text('${entry.key} · ${entry.value}'),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 20),
          LocalizedText(
            'Available management domains',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final entry in groups.entries)
            Card(
              child: ExpansionTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(entry.value.icon, size: 20),
                ),
                title: LocalizedText(entry.key),
                subtitle: LocalizedText(
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
                      trailing: _MethodChip(endpoint.method),
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

/// HTTP 方法色编码徽章（GET 绿 / POST 蓝 / PUT 琥珀 / DELETE 红）。
class _MethodChip extends StatelessWidget {
  final String method;

  const _MethodChip(this.method);

  Color get _color {
    if (method == 'GET') return AppColors.success;
    if (method == 'POST') return AppColors.accentBlue;
    if (method == 'PUT' || method == 'PATCH') return AppColors.warning;
    if (method == 'DELETE') return AppColors.danger;
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      method,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _color,
      ),
    ),
  );
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
