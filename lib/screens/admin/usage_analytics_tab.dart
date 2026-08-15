import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/sparkline.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';

import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'usage_analytics_contract.dart';

class UsageAnalyticsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const UsageAnalyticsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<UsageAnalyticsTab> createState() => _UsageAnalyticsTabState();
}

class _UsageAnalyticsTabState extends State<UsageAnalyticsTab> {
  static const _topPath = '/api/v1/admin/usage/top-tenants';
  static const _usagePath = '/api/v1/admin/tokens/usage';
  static const _subjectPath = '/api/v1/admin/tokens/subjects/{subject}';
  static const _linkedSessionsPath = '/api/v1/admin/sessions/linked/{subject}';

  /// 模块组色（tenants → amber）：页头与区块图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.usageAnalytics);

  final _startCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  Map<String, dynamic>? _topTenants;
  Map<String, dynamic>? _tokenUsage;
  Map<String, dynamic>? _subjectTokens;
  Map<String, dynamic>? _linkedSessions;
  String _period = 'day';
  String? _error;
  bool _loading = false;
  bool _subjectLoading = false;

  bool _has(String path) =>
      widget.capabilities.has('GET', path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) => endpoint.method == 'GET' && endpoint.path == path,
      );

  @override
  void initState() {
    super.initState();
    _startCtrl.text = DateTime.now().toUtc().toIso8601String().split('T').first;
    _load();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _clientCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _topTenants = null;
      _tokenUsage = null;
    });
    final jobs = <Future<(String, Map<String, dynamic>?, Object?)>>[
      if (_has(_topPath)) _read('tenants', _topPath, query: {'period': _period, 'start': _startCtrl.text.trim(), 'limit': '20'}),
      if (_has(_usagePath)) _read('tokens', _usagePath, query: {if (_clientCtrl.text.trim().isNotEmpty) 'client_id': _clientCtrl.text.trim()}),
    ];
    final results = await Future.wait(jobs);
    if (!mounted) return;
    final errors = <String>[];
    setState(() {
      for (final r in results) {
        if (r.$3 != null) {
          errors.add('${r.$1}: ${r.$3}');
        } else if (r.$1 == 'tenants') {
          _topTenants = normalizeTopTenantsPayload(r.$2!);
        } else {
          _tokenUsage = r.$2;
        }
      }
      if (jobs.isEmpty) {
        _error = 'Usage analytics is not enabled.';
      } else if (errors.isNotEmpty) {
        _error = 'Some usage data is unavailable — ${errors.join(' · ')}';
      }
      _loading = false;
    });
  }

  Future<void> _inspectSubject() async {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      setState(() => _error = 'Enter a subject identifier.');
      return;
    }
    setState(() {
      _subjectLoading = true;
      _error = null;
      _subjectTokens = null;
      _linkedSessions = null;
    });
    final encoded = Uri.encodeComponent(subject);
    final results = await Future.wait([
      if (_has(_subjectPath)) _read('tokens', '/api/v1/admin/tokens/subjects/$encoded', query: {if (_clientCtrl.text.trim().isNotEmpty) 'client_id': _clientCtrl.text.trim()}),
      if (_has(_linkedSessionsPath)) _read('sessions', '/api/v1/admin/sessions/linked/$encoded'),
    ]);
    if (!mounted) return;
    final errors = <String>[];
    setState(() {
      for (final r in results) {
        if (r.$3 != null) {
          errors.add('${r.$1}: ${r.$3}');
        } else if (r.$1 == 'tokens') {
          _subjectTokens = r.$2;
        } else {
          _linkedSessions = r.$2;
        }
      }
      if (errors.isNotEmpty) {
        _error = 'Some subject data is unavailable — ${errors.join(' · ')}';
      }
    });
    if (mounted) {
      setState(() {
        if (results.isEmpty) _error = 'Subject investigation is not enabled.';
        _subjectLoading = false;
      });
    }
  }

  Future<(String, Map<String, dynamic>?, Object?)> _read(
    String key,
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      return (key, await widget.api.get(path, query: query), null);
    } on SnaplinkAdminApiError catch (error) {
      return (key, null, error);
    } catch (error) {
      return (key, null, error);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      Row(
        children: [
          Icon(Icons.insights_outlined, color: _accent),
          const SizedBox(width: 8),
          Semantics(container: true, header: true, child: LocalizedText('Usage and session insights', style: Theme.of(context).textTheme.headlineSmall)),
          const Spacer(),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'.localized),
        ],
      ),
      const SizedBox(height: 4),
      const LocalizedText('Operational telemetry is aggregated and may lag live authentication traffic slightly.'),
      const SizedBox(height: 12),
      _filters(context),
      if (_error != null) ...[
        const SizedBox(height: 8),
        _errorCard(context),
      ],
      if (_loading) ...[
        const SizedBox(height: 20),
        const SkeletonListTile(itemCount: 3, variant: SkeletonVariant.card, delay: Duration(milliseconds: 150)),
      ],
      if (!_loading) ...[
        const SizedBox(height: 12),
        _metricStrip(context),
        const SizedBox(height: 12),
        _tenantLeaderboard(context),
        const SizedBox(height: 12),
        _tokenBuckets(context),
      ],
      const SizedBox(height: 12),
      _subjectInspector(context),
    ],
  );

  Widget _filters(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 150, child: DropdownButtonFormField<String>(
            initialValue: _period,
            decoration: InputDecoration(labelText: 'Period'.localized),
            items: const [
              DropdownMenuItem(value: 'day', child: LocalizedText('Day')),
              DropdownMenuItem(value: 'month', child: LocalizedText('Month')),
            ],
            onChanged: (value) => setState(() => _period = value!),
          )),
          SizedBox(width: 180, child: TextField(
            controller: _startCtrl,
            decoration: InputDecoration(labelText: 'Start date'.localized, hintText: 'YYYY-MM-DD'.localized),
          )),
          SizedBox(width: 220, child: TextField(
            controller: _clientCtrl,
            decoration: InputDecoration(labelText: 'Client ID filter'.localized),
          )),
          FilledButton(onPressed: _loading ? null : _load, child: const LocalizedText('Apply filters')),
        ],
      ),
    ),
  );

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）。
  Widget _errorCard(BuildContext context) => ErrorStateCard(
    message: _error!,
    onRetry: _load,
    retryEnabled: !_loading,
  );

  /// 页头指标卡：缺失字段不求和、不虚构总量；出错时整条隐藏（数据诚实）。
  Widget _metricStrip(BuildContext context) {
    if (_error != null) return const SizedBox.shrink();
    final tenants = ((_topTenants?['tenants'] as List?) ?? const []).whereType<Map>().toList();
    final cards = <KeyMetricCard>[
      if (_tokenUsage?['total'] is num)
        KeyMetricCard(label: 'Token requests', value: _tokenUsage!['total'] as num, icon: Icons.electric_bolt_outlined, color: _accent),
      if (tenants.isNotEmpty)
        for (final (field, label, icon) in const [
          ('logins', 'Logins', Icons.login),
          ('tokens_issued', 'Tokens issued', Icons.token_outlined),
          ('active_users', 'Active users', Icons.people_outline),
        ])
          KeyMetricCard(label: label, value: sumTenantMetric(tenants, field), caption: 'Across top tenants', icon: icon, color: _accent),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return MetricStrip(cards: cards);
  }

  Widget _tenantLeaderboard(BuildContext context) {
    final metrics = ((_topTenants?['tenants'] as List?) ?? const []).whereType<Map>().toList();
    final maxLogins = metrics.fold<num>(0, (max, t) {
      final v = t['logins'];
      return v is num && v > max ? v : max;
    });
    return _section(
      context,
      'Top tenants',
      [
        if (metrics.isEmpty)
          _empty('Tenant usage metering is unavailable or has no data.')
        else
          _table(minWidth: 720, itemCount: metrics.length, columns: [
            AdminDataColumn(id: 'rank', label: 'RANK', width: 56, builder: (context, i) => TableCellText('${i + 1}', muted: true)),
            AdminDataColumn(id: 'tenant', label: 'TENANT', width: 220, cardPrimary: true, builder: (context, i) => TableCellText(metrics[i]['tenant_name']?.toString() ?? metrics[i]['tenant_id']?.toString() ?? 'Tenant', bold: true)),
            AdminDataColumn(id: 'metrics', label: 'METRICS', width: 260, cardDetail: true, builder: (context, i) => TableCellText(formatUsageMetricSummary(metrics[i]), muted: true, maxLines: 2)),
            AdminDataColumn(id: 'usage', label: 'LOGIN SHARE', width: 180, builder: (context, i) => maxLogins <= 0 ? const SizedBox.shrink() : DistributionBar(segments: [DistributionSegment(label: 'logins', value: (metrics[i]['logins'] as num? ?? 0).toInt(), color: _accent)], total: maxLogins.toInt(), showLegend: false, height: 4)),
          ]),
      ],
      icon: Icons.business_outlined,
    );
  }

  Widget _tokenBuckets(BuildContext context) {
    final buckets = _tokenUsage?['buckets'] as List? ?? const [];
    final rows = buckets.take(50).whereType<Map>().toList();
    return _section(
      context,
      'Token traffic',
      [
        if (buckets.isEmpty)
          _empty('Token usage telemetry is unavailable or has no data.')
        else ...[
          if (buckets.length >= 3)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Sparkline(data: [...buckets.take(30).map((raw) => ((raw as Map)['count'] as num?) ?? 0)], height: 36)),
          _table(minWidth: 680, itemCount: rows.length, columns: [
            AdminDataColumn(id: 'token', label: 'CLIENT · KIND', width: 260, cardPrimary: true, builder: (context, i) {
              final row = rows[i];
              final peak = i < 3 && ((row['count'] as num?) ?? 0) > 0;
              return TableCellText('${row['client_id'] ?? 'unknown client'} · ${row['kind'] ?? 'token'}', bold: peak, color: peak ? AppColors.danger : null);
            }),
            AdminDataColumn(id: 'detail', label: 'ENDPOINT · MINUTE', width: 280, cardDetail: true, builder: (context, i) => TableCellText('${rows[i]['endpoint'] ?? ''} · ${rows[i]['minute'] ?? ''}', muted: true, maxLines: 2)),
            AdminDataColumn(id: 'count', label: 'COUNT', width: 140, builder: (context, i) {
              final count = (rows[i]['count'] as num?) ?? 0;
              final peak = i < 3 && count > 0;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                if (peak) StatusChip(label: 'Peak', color: AppColors.danger, icon: Icons.local_fire_department),
                const SizedBox(width: 8),
                Text('$count'),
              ]);
            }),
          ]),
          if (buckets.length > 50) Text('${buckets.length - 50} additional buckets omitted.'),
        ],
      ],
      icon: Icons.electric_bolt_outlined,
    );
  }

  Widget _subjectInspector(BuildContext context) => _section(
    context,
    'Subject investigation',
    [
      const LocalizedText('Inspect active refresh-token counts and linked OIDC/SAML session legs without exposing credential values.'),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: TextField(controller: _subjectCtrl, decoration: InputDecoration(labelText: 'Subject'.localized), onSubmitted: (_) => _inspectSubject())),
          const SizedBox(width: 12),
          FilledButton(onPressed: _subjectLoading ? null : _inspectSubject, child: const LocalizedText('Inspect')),
        ],
      ),
      if (_subjectLoading) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (_subjectTokens != null) ...[
        const SizedBox(height: 12),
        _jsonResult('Active token count', _subjectTokens!),
      ],
      if (_linkedSessions != null) ...[
        const SizedBox(height: 12),
        _jsonResult('Cross-protocol sessions', _linkedSessions!),
      ],
    ],
    icon: Icons.manage_search,
  );

  Widget _table({required double minWidth, required int itemCount, required List<AdminDataColumn> columns}) => AdminDataTable(
    density: TableDensity.compact,
    minWidth: minWidth,
    columns: columns,
    itemCount: itemCount,
    rowBuilder: (context, i) => const SizedBox.shrink(),
  );

  Widget _empty(String title) =>
      EmptyState(variant: EmptyStateVariant.empty, compact: true, title: title);

  Widget _section(BuildContext context, String title, List<Widget> children, {IconData? icon}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: _accent), const SizedBox(width: 8)],
              LocalizedText(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const Divider(),
          ...children,
        ],
      ),
    ),
  );

  Widget _jsonResult(String title, Map<String, dynamic> value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LocalizedText(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      SelectableText(const JsonEncoder.withIndent('  ').convert(value), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    ],
  );
}
