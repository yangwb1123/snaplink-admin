import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';

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
    final jobs = [
      if (_has(_topPath))
        _read(
          'tenants',
          _topPath,
          query: {
            'period': _period,
            'start': _startCtrl.text.trim(),
            'limit': '20',
          },
        ),
      if (_has(_usagePath))
        _read(
          'tokens',
          _usagePath,
          query: {
            if (_clientCtrl.text.trim().isNotEmpty)
              'client_id': _clientCtrl.text.trim(),
          },
        ),
    ];
    final results = await Future.wait(jobs);
    if (!mounted) return;
    final errors = <String>[];
    setState(() {
      for (final result in results) {
        if (result.$3 != null) {
          errors.add('${result.$1}: ${result.$3}');
        } else if (result.$1 == 'tenants') {
          _topTenants = normalizeTopTenantsPayload(result.$2!);
        } else {
          _tokenUsage = result.$2;
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
      if (_has(_subjectPath))
        _read(
          'tokens',
          '/api/v1/admin/tokens/subjects/$encoded',
          query: {
            if (_clientCtrl.text.trim().isNotEmpty)
              'client_id': _clientCtrl.text.trim(),
          },
        ),
      if (_has(_linkedSessionsPath))
        _read('sessions', '/api/v1/admin/sessions/linked/$encoded'),
    ]);
    if (!mounted) return;
    final errors = <String>[];
    setState(() {
      for (final result in results) {
        if (result.$3 != null) {
          errors.add('${result.$1}: ${result.$3}');
        } else if (result.$1 == 'tokens') {
          _subjectTokens = result.$2;
        } else {
          _linkedSessions = result.$2;
        }
      }
      if (errors.isNotEmpty) {
        _error = 'Some subject data is unavailable — ${errors.join(' · ')}';
      }
    });
    if (results.isEmpty && mounted) {
      setState(() => _error = 'Subject investigation is not enabled.');
    }
    if (mounted) setState(() => _subjectLoading = false);
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
          LocalizedText(
            'Usage and session insights',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh'.localized,
          ),
        ],
      ),
      const SizedBox(height: 4),
      const LocalizedText(
        'Operational telemetry is aggregated and may lag live authentication traffic slightly.',
      ),
      const SizedBox(height: 12),
      _filters(context),
      if (_error != null) ...[
        const SizedBox(height: 8),
        LocalizedText(_error!, style: const TextStyle(color: AppColors.danger)),
      ],
      if (_loading) ...[
        const SizedBox(height: 20),
        const Center(child: CircularProgressIndicator()),
      ],
      if (!_loading) ...[
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
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: InputDecoration(labelText: 'Period'.localized),
              items: const [
                DropdownMenuItem(value: 'day', child: LocalizedText('Day')),
                DropdownMenuItem(value: 'month', child: LocalizedText('Month')),
              ],
              onChanged: (value) => setState(() => _period = value!),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _startCtrl,
              decoration: InputDecoration(
                labelText: 'Start date'.localized,
                hintText: 'YYYY-MM-DD'.localized,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _clientCtrl,
              decoration: InputDecoration(
                labelText: 'Client ID filter'.localized,
              ),
            ),
          ),
          FilledButton(
            onPressed: _loading ? null : _load,
            child: const LocalizedText('Apply filters'),
          ),
        ],
      ),
    ),
  );

  Widget _tenantLeaderboard(BuildContext context) {
    final tenants = _topTenants?['tenants'] as List? ?? const [];
    return _section(
      context,
      'Top tenants',
      tenants.isEmpty
          ? const [
              LocalizedText(
                'Tenant usage metering is unavailable or has no data.',
              ),
            ]
          : [
              for (var index = 0; index < tenants.length; index++)
                ListTile(
                  leading: CircleAvatar(child: LocalizedText('${index + 1}')),
                  title: LocalizedText(
                    (tenants[index] as Map)['tenant_name']?.toString() ??
                        (tenants[index] as Map)['tenant_id']?.toString() ??
                        'Tenant',
                  ),
                  subtitle: Text(
                    formatUsageMetricSummary(tenants[index] as Map),
                  ),
                ),
            ],
    );
  }

  Widget _tokenBuckets(BuildContext context) {
    final buckets = _tokenUsage?['buckets'] as List? ?? const [];
    return _section(
      context,
      'Token traffic',
      buckets.isEmpty
          ? const [
              LocalizedText(
                'Token usage telemetry is unavailable or has no data.',
              ),
            ]
          : [
              for (final raw in buckets.take(50))
                Builder(
                  builder: (_) {
                    final bucket = raw as Map;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.token_outlined),
                      title: LocalizedText(
                        '${bucket['client_id'] ?? 'unknown client'} · ${bucket['kind'] ?? 'token'}',
                      ),
                      subtitle: LocalizedText(
                        '${bucket['endpoint'] ?? ''} · ${bucket['minute'] ?? ''}',
                      ),
                      trailing: LocalizedText('${bucket['count'] ?? 0}'),
                    );
                  },
                ),
              if (buckets.length > 50)
                LocalizedText(
                  '${buckets.length - 50} additional buckets omitted.',
                ),
            ],
    );
  }

  Widget _subjectInspector(
    BuildContext context,
  ) => _section(context, 'Subject investigation', [
    const LocalizedText(
      'Inspect active refresh-token counts and linked OIDC/SAML session legs without exposing credential values.',
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _subjectCtrl,
            decoration: InputDecoration(labelText: 'Subject'.localized),
            onSubmitted: (_) => _inspectSubject(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _subjectLoading ? null : _inspectSubject,
          child: const LocalizedText('Inspect'),
        ),
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
  ]);

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
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
      SelectableText(
        const JsonEncoder.withIndent('  ').convert(value),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    ],
  );
}
