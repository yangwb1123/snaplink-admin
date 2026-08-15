import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/sensitive_data.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/info_row.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'connections/connection_contract.dart';

/// Connection detail screen.
/// URL: /admin/connections/{id}
///
/// 复用 ConnectionAdminContract 的端点路径（与工作台标签页同一契约），
/// secret 经 SensitiveData.redact 脱敏后才渲染，健康探测语义保持。
class ConnectionDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String connectionId;

  const ConnectionDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.connectionId,
  });

  @override
  State<ConnectionDetailScreen> createState() => _ConnectionDetailScreenState();
}

class _ConnectionDetailScreenState extends State<ConnectionDetailScreen> {
  Map<String, dynamic>? _conn;
  Map<String, dynamic>? _health;
  String? _error;
  bool _loading = true;
  bool _showConfig = false;

  /// 模块强调色（connections → security 组 rose）。
  Color get _accent => adminModuleIconColor('connections');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cid = widget.connectionId;
      final results = await Future.wait([
        widget.api.get(ConnectionAdminContract.detail(cid)),
        widget.api
            .get(ConnectionAdminContract.health(cid))
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _conn = results[0] as Map<String, dynamic>?;
        _health = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Semantics(
        container: true,
        header: true,
        child: LocalizedText(
          'Connection: {widget_connectionId}',
          args: {'widget_connectionId': widget.connectionId},
        ),
      ),
      leading: IconButton(
        tooltip: 'Back'.localized,
        icon: const Icon(Icons.arrow_back),
        onPressed: () => AdminRoute.back('connections'),
      ),
    ),
    body: _loading
        ? const SkeletonListTile(itemCount: 4)
        : _error != null
        ? ErrorStateView(message: _error!, onRetry: _load)
        : Column(
            children: [
              AdminBreadcrumb(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoCard(context),
                      const SizedBox(height: 16),
                      ..._healthCardSections(context),
                      const SizedBox(height: 16),
                      _configCard(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );

  List<Widget> _healthCardSections(BuildContext context) => [
    if (_health != null && _health!.isNotEmpty) _healthCard(context),
  ];

  Widget _infoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 40, color: _accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conn?['name']?.toString() ??
                          _conn?['display_name']?.toString() ??
                          widget.connectionId,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    LocalizedText(
                      'ID: {id}',
                      args: {'id': _conn?['id'] ?? widget.connectionId},
                    ),
                  ],
                ),
              ),
              _statusChip(),
            ],
          ),
          const Divider(),
          InfoRow(
            label: 'Provider',
            value: _conn?['provider']?.toString() ?? '—',
            labelWidth: 100,
          ),
          InfoRow(
            label: 'Type',
            value: _conn?['type']?.toString() ??
                _conn?['connection_type']?.toString() ??
                '—',
            labelWidth: 100,
          ),
          InfoRow(
            label: 'Domains',
            value: (_conn?['domains'] as List?)?.join(', ') ?? '—',
            labelWidth: 100,
          ),
          InfoRow(
            label: 'Client ID',
            value: _conn?['client_id']?.toString() ?? '—',
            labelWidth: 100,
            level: DataEmphasisLevel.secondary,
          ),
          InfoRow(
            label: 'Issuer',
            value: _conn?['issuer']?.toString() ?? '—',
            labelWidth: 100,
          ),
        ],
      ),
    ),
  );

  Widget _statusChip() {
    final status = _conn?['status']?.toString() ?? 'active';
    final isHealthy = _health?['healthy'] == true;
    return Column(
      children: [
        if (status == 'active')
          StatusChip.active(label: 'Active')
        else if (status == 'suspended')
          StatusChip.suspended(label: 'Suspended')
        else
          StatusChip.inactive(label: status),
        if (_health != null && _health!.isNotEmpty)
          isHealthy ? StatusChip.healthy() : StatusChip.unhealthy(),
      ],
    );
  }

  Widget _healthCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 20, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: LocalizedText(
                  'Health',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(
            label: 'Last checked',
            value: formatServerTime(_health?['last_checked']),
            labelWidth: 100,
          ),
          InfoRow(
            label: 'Latency',
            value: _health?['latency_ms']?.toString() != null
                ? '${_health!['latency_ms']}ms'
                : '—',
            labelWidth: 100,
          ),
          InfoRow(
            label: 'Error',
            value: _health?['error']?.toString() ?? 'none',
            labelWidth: 100,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _probe(),
            icon: Icon(Icons.refresh, color: _accent),
            label: const LocalizedText('Probe now'),
          ),
        ],
      ),
    ),
  );

  Future<void> _probe() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Probe upstream connection?',
      message:
          'Snaplink will contact the configured upstream identity provider '
          'and record the result.',
      confirmLabel: 'Run probe',
    );
    if (!confirmed) return;
    try {
      final result = await widget.api.post(
        ConnectionAdminContract.probe(widget.connectionId),
        {},
      );
      if (!mounted) return;
      final h = result as Map<String, dynamic>?;
      setState(() => _health = h);
      final healthy = h?['healthy'] == true;
      showAppSnackBar(
        context,
        content: LocalizedText(healthy ? 'Connection healthy' : 'Probe failed'),
        kind: healthy ? AppSnackBarKind.success : AppSnackBarKind.error,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          content: LocalizedText('Error: {detail}', args: {'detail': e}),
          kind: AppSnackBarKind.error,
        );
      }
    }
  }

  Widget _configCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showConfig = !_showConfig),
            child: Row(
              children: [
                Icon(Icons.tune_outlined, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: LocalizedText(
                    'Configuration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(_showConfig ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (_showConfig && _conn != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(
                  SensitiveData.redact(
                    Map<String, dynamic>.from(_conn!)
                      ..remove('id')
                      ..remove('name'),
                  ),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
