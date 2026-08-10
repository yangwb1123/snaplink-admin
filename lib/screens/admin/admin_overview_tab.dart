import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/hover_card.dart';
import 'package:sso_admin/widgets/progress_ring.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/operator_persona.dart';

import 'admin_overview_metrics.dart';
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

  /// Persona emphasis (derived by the dashboard; default = no emphasis).
  final OperatorPersona persona;
  final bool commerceAvailable;
  final Object? commerceProbeError;

  const AdminOverviewTab({
    super.key,
    required this.endpoints,
    required this.loadError,
    required this.onRefresh,
    this.persona = OperatorPersona.general,
    this.commerceAvailable = false,
    this.commerceProbeError,
  });

  @override
  Widget build(BuildContext context) {
    final capabilities = SnaplinkAdminCapabilities(endpoints);
    final groups = _groupEndpoints(endpoints);
    final documentedOnly = SnaplinkAdminOperationCatalog.endpoints
        .where((endpoint) => !capabilities.has(endpoint.method, endpoint.path))
        .length;
    final running = endpoints.length;
    final orderedGroupKeys = personaGroupOrder(
      groups.keys.toList(growable: false),
      persona,
      pathsByGroup: {
        for (final entry in groups.entries)
          entry.key: [
            for (final endpoint in entry.value.endpoints) endpoint.path,
          ],
      },
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 品牌 hero：浅渐变 + 标题 + 摘要 + 刷新（Vercel/Supabase 风格头部）。
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.of(context).platformOverview,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh capabilities'.localized,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const LocalizedText(
                'Runtime inventory of every module this replica advertises, with OpenAPI-only fallbacks.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              // 健康中心（信息优先级：健康度大数字第一眼可见）+ 指标条。
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HealthRing(
                    healthy: running,
                    total: running + documentedOnly,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OverviewMetrics(
                          endpoints: endpoints,
                          featureGroups: capabilities.featureCounts.length,
                          documentedOnly: documentedOnly,
                          commerceAvailable: commerceAvailable,
                          commerceProbeError: commerceProbeError,
                          persona: persona,
                        ),
                        const SizedBox(height: 12),
                        // 运行覆盖率：文档契约 vs 运行端点（数据表达对比条）。
                        DistributionBar(
                          segments: [
                            DistributionSegment(
                              label: 'Running',
                              value: running,
                              color: AppColors.primary,
                            ),
                            DistributionSegment(
                              label: 'Documented-only',
                              value: documentedOnly,
                              color: AppColors.warning,
                            ),
                          ],
                          total: running + documentedOnly,
                        ),
                        const SizedBox(height: 4),
                        LocalizedText(
                          '$running running · $documentedOnly documented-only',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        else
          // 异常优先（信息优先级 05）：就绪/风险一句话 + 色编码。
          _StatusCard(
            icon: documentedOnly == 0
                ? Icons.verified_user_outlined
                : Icons.warning_amber_outlined,
            title: documentedOnly == 0
                ? 'All contract routes are live'
                : '$documentedOnly documented routes not advertised',
            body: documentedOnly == 0
                ? 'Every OpenAPI contract route is advertised by this replica — no fallback access needed.'
                : 'OpenAPI-only modules stay visible for compatibility and report 404/501 as not enabled. '
                      'Probe the module to confirm it is intentional.',
            color: documentedOnly == 0 ? AppColors.success : AppColors.warning,
          ),
        // 诚实性披露：persona 来自能力清单而非身份（design §3.3）。
        const SizedBox(height: 8),
        Row(
          children: [
            StatusChip.info(
              label: context.tr('Persona: {persona}', {
                'persona': context.tr(personaLabelKey(persona)),
              }),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: context.tr(
                'Persona is derived from the server capability inventory, not from your identity.',
              ),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (loadError == null && endpoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionHeader('Enabled feature surfaces'),
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
          SectionHeader('Available management domains'),
          const SizedBox(height: 8),
          for (final key in orderedGroupKeys)
            _endGroupCard(context, MapEntry(key, groups[key]!)),
        ],
      ],
    );
  }

  Widget _endGroupCard(
    BuildContext context,
    MapEntry<String, _EndpointGroup> entry,
  ) => Card(
    child: ExpansionTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(entry.value.icon, size: 20),
      ),
      title: LocalizedText(entry.key),
      subtitle: LocalizedText('${entry.value.endpoints.length} live endpoints'),
      children: [..._endpointTiles(entry.value.endpoints)],
    ),
  );

  List<Widget> _endpointTiles(List<SnaplinkAdminEndpoint> endpoints) => [
    for (final endpoint in endpoints)
      ListTile(
        dense: true,
        title: Text(
          endpoint.path,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        trailing: _MethodChip(endpoint.method),
      ),
  ];

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

/// Hero 统计项：健康度环（ProgressRing 数据表达——健康度图形化）。
class _HealthRing extends StatelessWidget {
  final int healthy;
  final int total;

  const _HealthRing({required this.healthy, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = total == 0 ? 0.0 : healthy * 100.0 / total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          value: percent,
          size: 76,
          strokeWidth: 7,
          label: '${percent.round()}%',
        ),
        const SizedBox(height: 4),
        LocalizedText(
          'Runtime health',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
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
    return HoverCard(
      child: Card(
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
      ),
    );
  }
}
