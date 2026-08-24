import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/hover_card.dart';
import 'package:sso_admin/widgets/progress_ring.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_overview_metrics.dart';
import 'snaplink_admin_api.dart';

/// Runtime inventory landing page. Counts stay as cards; endpoint
/// relationships stay as expandable lists rather than a summary table.
class AdminOverviewTab extends StatefulWidget {
  final List<SnaplinkAdminEndpoint> endpoints;
  final Object? loadError;
  final VoidCallback onRefresh;
  final OperatorPersona persona;
  final bool commerceAvailable;
  final Object? commerceProbeError;

  /// Optional state supplied by a caller that can distinguish loading from an
  /// intentionally empty response. The existing dashboard keeps its empty
  /// initial-inventory fallback for compatibility.
  final bool? isLoading;

  const AdminOverviewTab({
    super.key,
    required this.endpoints,
    required this.loadError,
    required this.onRefresh,
    this.persona = OperatorPersona.general,
    this.commerceAvailable = false,
    this.commerceProbeError,
    this.isLoading,
  });

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  bool _resolved = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _resolved = widget.isLoading == false ||
        (widget.isLoading == null &&
            (widget.endpoints.isNotEmpty ||
                widget.loadError != null ||
                !identical(widget.endpoints, const <SnaplinkAdminEndpoint>[])));
  }

  List<SnaplinkAdminEndpoint> get endpoints => widget.endpoints;
  Object? get loadError => widget.loadError;
  OperatorPersona get persona => widget.persona;
  bool get commerceAvailable => widget.commerceAvailable;
  Object? get commerceProbeError => widget.commerceProbeError;
  bool? get isLoading => widget.isLoading;

  @override
  void didUpdateWidget(covariant AdminOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != null) return;
    if (widget.loadError != oldWidget.loadError) {
      _refreshing = widget.loadError == null;
      _resolved = widget.loadError != null;
    }
    if (!identical(widget.endpoints, oldWidget.endpoints)) {
      _refreshing = false;
      _resolved = true;
    }
  }

  void _refresh() {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = SnaplinkAdminCapabilities(endpoints);
    final groups = _groupEndpoints(endpoints, Theme.of(context).brightness);
    final documentedOnly = SnaplinkAdminOperationCatalog.endpoints
        .where((endpoint) => !capabilities.has(endpoint.method, endpoint.path))
        .length;
    final loading = isLoading ??
        (_refreshing || (endpoints.isEmpty && !_resolved && loadError == null));
    final empty = !loading && loadError == null && endpoints.isEmpty;
    final known = !loading && loadError == null && endpoints.isNotEmpty;
    final VoidCallback? refresh = _refreshing ? null : _refresh;
    final order = personaGroupOrder(
      groups.keys.toList(growable: false),
      persona,
      pathsByGroup: {
        for (final entry in groups.entries)
          entry.key: [for (final endpoint in entry.value.endpoints) endpoint.path],
      },
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Hero(
          running: endpoints.length,
          documentedOnly: documentedOnly,
          inventoryKnown: known,
          onRefresh: refresh,
          metrics: OverviewMetrics(
            endpoints: endpoints,
            featureGroups: capabilities.featureCounts.length,
            documentedOnly: documentedOnly,
            commerceAvailable: commerceAvailable,
            commerceProbeError: commerceProbeError,
            persona: persona,
            showValues: known,
          ),
        ),
        const SizedBox(height: 12),
        if (loadError != null)
          _StatusCard(
            icon: Icons.cloud_off,
            title: 'Capability inventory is unavailable',
            body: 'The console is using its versioned OpenAPI catalog and will probe optional pages safely.',
            detail: 'Runtime error: {error}',
            detailArgs: {'error': loadError.toString()},
            color: AppColors.warning,
            onRetry: refresh,
          )
        else if (loading) ...[
          const _StatusCard(
            icon: Icons.hourglass_empty,
            title: 'Loading runtime capabilities',
            body: 'Contract-backed modules remain discoverable while this replica is queried.',
            color: AppColors.accentBlue,
          ),
          const SizedBox(height: 12),
          const SkeletonListTile(itemCount: 4, variant: SkeletonVariant.card),
        ] else if (empty)
          EmptyState(
            variant: EmptyStateVariant.empty,
            title: 'No data available',
            subtitle: 'The data may have changed since you last loaded this page.',
            actionLabel: 'Refresh capabilities',
            actionIcon: Icons.refresh,
            onAction: refresh,
          )
        else ...[
          _StatusCard(
            icon: documentedOnly == 0 ? Icons.verified_user_outlined : Icons.warning_amber_outlined,
            title: documentedOnly == 0 ? 'All contract routes are live' : '{count} documented routes not advertised',
            titleArgs: documentedOnly == 0 ? null : {'count': documentedOnly},
            body: documentedOnly == 0
                ? 'Every OpenAPI contract route is advertised by this replica — no fallback access needed.'
                : 'OpenAPI-only modules stay visible for compatibility and report 404/501 as not enabled. Probe the module to confirm it is intentional.',
            color: documentedOnly == 0 ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(height: 8),
          _PersonaDisclosure(persona: persona),
          const SizedBox(height: 16),
          SectionHeader('Enabled feature surfaces'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in capabilities.featureCounts.entries) Chip(label: Text('${entry.key} · ${entry.value}')),
          ]),
          const SizedBox(height: 20),
          SectionHeader('Available management domains'),
          const SizedBox(height: 8),
          for (final key in order) _GroupCard(MapEntry(key, groups[key]!)),
        ],
      ],
    );
  }

  Map<String, _EndpointGroup> _groupEndpoints(List<SnaplinkAdminEndpoint> values, Brightness brightness) {
    final groups = <String, _EndpointGroup>{};
    for (final endpoint in values) {
      final group = _groupFor(endpoint.path, brightness);
      groups.putIfAbsent(group.$1, () => _EndpointGroup(group.$2, group.$3)).endpoints.add(endpoint);
    }
    return groups;
  }

  (String, IconData, Color) _groupFor(String path, Brightness brightness) {
    if (path.contains('/clients') || path.contains('/register')) return ('Applications and OAuth', Icons.apps_outlined, adminGroupIconColorFor('identity', brightness));
    if (path.contains('/users') || path.contains('/local-users') || path.contains('/connections')) return ('Identity and connections', Icons.people_outline, adminGroupIconColorFor('identity', brightness));
    if (path.contains('/tenants') || path.contains('/domains')) return ('Tenants and organizations', Icons.business_outlined, adminGroupIconColorFor('tenants', brightness));
    if (path.contains('/tokens') || path.contains('/sessions') || path.contains('/logout')) return ('Tokens and sessions', Icons.security_outlined, adminGroupIconColorFor('security', brightness));
    if (path.contains('/keys') || path.contains('/credentials') || path.contains('/break-glass')) return ('Security operations', Icons.key_outlined, adminGroupIconColorFor('security', brightness));
    if (path.contains('/compliance') || path.contains('/changes') || path.contains('/audit') || path.contains('/policy')) return ('Governance and compliance', Icons.gavel_outlined, adminGroupIconColorFor('system', brightness));
    if (path.contains('/snapshots') || path.contains('/releases') || path.contains('/backup') || path.contains('/dr/') || path.contains('/health') || path.contains('/config')) return ('Platform operations', Icons.monitor_heart_outlined, adminGroupIconColorFor('overview', brightness));
    return ('Other exposed APIs', Icons.extension_outlined, adminGroupIconColorFor('other', brightness));
  }
}

class _Hero extends StatelessWidget {
  final int running, documentedOnly;
  final bool inventoryKnown;
  final Widget metrics;
  final VoidCallback? onRefresh;

  const _Hero({required this.running, required this.documentedOnly, required this.inventoryKnown, required this.metrics, required this.onRefresh});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final health = _HealthRing(healthy: running, total: running + documentedOnly, known: inventoryKnown);
    final stats = _stats(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
          Theme.of(context).colorScheme.surface,
        ]),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(context),
        const SizedBox(height: 16),
        if (constraints.maxWidth < 620)
          Column(children: [health, const SizedBox(height: 16), stats])
        else
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [health, const SizedBox(width: 20), Expanded(child: stats)]),
      ]),
    );
  });

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.dashboard_outlined, color: adminModuleIconColor(AdminModuleId.overview), size: 28),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(container: true, header: true, child: Text(AppStrings.of(context).platformOverview, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 4),
        const LocalizedText('Runtime inventory of every module this replica advertises, with OpenAPI-only fallbacks.', style: TextStyle(fontSize: 13)),
      ])),
      IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh capabilities'.localized),
    ]);
  }

  Widget _stats(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      metrics,
      const SizedBox(height: 12),
      if (inventoryKnown) ...[
        DistributionBar(segments: [
          DistributionSegment(label: 'Running', value: running, color: AppColors.primary),
          DistributionSegment(label: 'Documented-only', value: documentedOnly, color: AppColors.warning),
        ], total: running + documentedOnly),
        const SizedBox(height: 4),
        LocalizedText('{running} running · {documented} documented-only', args: {'running': running, 'documented': documentedOnly}, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
      ] else
        StatusChip.unknown(label: context.tr('Unknown')),
    ]);
  }
}

class _GroupCard extends StatelessWidget {
  final MapEntry<String, _EndpointGroup> entry;
  const _GroupCard(this.entry);

  @override
  Widget build(BuildContext context) {
    final group = entry.value;
    return Card(child: ExpansionTile(
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: group.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(group.icon, size: 20, color: group.color)),
      title: LocalizedText(entry.key, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: LocalizedText('{count} live endpoints', args: {'count': group.endpoints.length}, maxLines: 1, overflow: TextOverflow.ellipsis),
      children: [for (final endpoint in group.endpoints) ListTile(dense: true, title: Text(endpoint.path, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)), trailing: _MethodChip(endpoint.method))],
    ));
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;
  final Map<String, Object?>? titleArgs, detailArgs;
  final String? detail;
  final VoidCallback? onRetry;

  const _StatusCard({required this.icon, required this.title, required this.body, required this.color, this.titleArgs, this.detail, this.detailArgs, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), effective = AppColors.semanticFor(theme.brightness, color);
    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LocalizedText(title, args: titleArgs, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      LocalizedText(body, style: muted),
      if (detail != null) ...[const SizedBox(height: 4), LocalizedText(detail!, args: detailArgs, style: muted)],
    ]);
    final action = onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const LocalizedText('Retry'));
    Widget leading() => Container(width: 40, height: 40, decoration: BoxDecoration(color: effective.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: effective, size: 22));
    return HoverCard(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: LayoutBuilder(builder: (context, constraints) {
      if (action == null || constraints.maxWidth >= 420) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [leading(), const SizedBox(width: 12), Expanded(child: copy), if (action != null) ...[const SizedBox(width: 8), action]]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [leading(), const SizedBox(width: 12), Expanded(child: copy)]),
        Align(alignment: AlignmentDirectional.centerEnd, child: Padding(padding: const EdgeInsets.only(top: 8), child: action)),
      ]);
    })));
  }
}

class _PersonaDisclosure extends StatelessWidget {
  final OperatorPersona persona;
  const _PersonaDisclosure({required this.persona});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 4, children: [
    StatusChip.info(label: context.tr('Persona: {persona}', {'persona': context.tr(personaLabelKey(persona))})),
    Tooltip(message: context.tr('Persona is derived from the server capability inventory, not from your identity.'), child: Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);
}

class _MethodChip extends StatelessWidget {
  final String method;
  const _MethodChip(this.method);
  Color get _color => switch (method) {
    'GET' => AppColors.success,
    'POST' => AppColors.accentBlue,
    'PUT' || 'PATCH' => AppColors.warning,
    'DELETE' => AppColors.danger,
    _ => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.semanticFor(Theme.of(context).brightness, _color);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)), child: Text(method, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)));
  }
}

class _EndpointGroup {
  final IconData icon;
  final Color color;
  final List<SnaplinkAdminEndpoint> endpoints = [];
  _EndpointGroup(this.icon, this.color);
}

class _HealthRing extends StatelessWidget {
  final int healthy, total;
  final bool known;
  const _HealthRing({required this.healthy, required this.total, required this.known});

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : healthy * 100.0 / total;
    final ring = known ? ProgressRing(value: percent, size: 76, strokeWidth: 7, label: '${percent.round()}%') : const _UnknownRing();
    return Column(mainAxisSize: MainAxisSize.min, children: [ring, const SizedBox(height: 4), LocalizedText('Runtime health', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))]);
  }
}

class _UnknownRing extends StatelessWidget {
  const _UnknownRing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(container: true, label: '${context.tr('Runtime health')}: ${context.tr('Unknown')}', excludeSemantics: true, child: SizedBox(width: 76, height: 76, child: Stack(fit: StackFit.expand, children: [
      CircularProgressIndicator(value: 0, strokeWidth: 7, color: scheme.onSurfaceVariant.withValues(alpha: 0.45), backgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.10)),
      Center(child: Text('—', style: Theme.of(context).textTheme.labelLarge)),
    ])));
  }
}
