import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_route.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'distributed_cluster_panel.dart';

/// System health dashboard.
/// Shows connection status to the backend, the distributed-cluster
/// (Tier B) control plane ([DistributedClusterPanel]), storage and
/// federation health, and quick actions.
class HealthTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  const HealthTab({super.key, required this.api});
  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> {
  Map<String, dynamic>? _health;
  Map<String, dynamic>? _storageHealth;
  Map<String, dynamic>? _federationHealth;
  String? _error;
  bool _loading = false;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _refresh();
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _quiet(String path) =>
      widget.api.get(path).catchError((_) => <String, dynamic>{});

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.get('/health'),
        _quiet('/api/v1/admin/storage-health'),
        _quiet('/api/v1/admin/federation/health'),
      ]);
      if (!mounted) return;
      setState(() {
        _health = results[0] as Map<String, dynamic>?;
        _storageHealth = results[1] as Map<String, dynamic>?;
        _federationHealth = results[2] as Map<String, dynamic>?;
        _error = null;
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      Row(
        children: [
          LocalizedText(
            'System Health',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh'.localized,
          ),
        ],
      ),
      const SizedBox(height: 4),
      const LocalizedText(
        'Health checks aggregate runtime reachability of the server, storage and cluster.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSubtle,
        ),
      ),
      const SizedBox(height: 8),
      // 健康总览（异常优先：三个子系统状态一眼可见）。
      _healthOverview(context),
      const SizedBox(height: 12),
      _serverCard(context),
      const SizedBox(height: 12),
      DistributedClusterPanel(api: widget.api),
      if (_storageHealth?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        _card(context, 'Storage Health', _storageHealth!, Icons.storage),
      ],
      if (_federationHealth?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        _card(context, 'Federation Health', _federationHealth!, Icons.lan),
      ],
      const SizedBox(height: 12),
      _debugCard(context),
    ],
  );

  /// 健康总览：子系统状态徽章组（双编码 + 异常优先）。
  Widget _healthOverview(BuildContext context) {
    final entries = <(String, bool, IconData)>[
      ('Server', _health?['status']?.toString() == 'ok',
       Icons.dns_outlined),
      ('Storage', _storageHealth?.isNotEmpty == true &&
          _storageStatusOk(_storageHealth!),
       Icons.storage_outlined),
      ('Federation', _federationHealth?.isNotEmpty == true &&
          _federationStatusOk(_federationHealth!),
       Icons.lan_outlined),
    ];
    final anyDown = entries.any((e) => !e.$2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              anyDown ? Icons.warning_amber_outlined : Icons.verified_user_outlined,
              color: anyDown ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LocalizedText(
                anyDown ? 'A subsystem needs attention' : 'All subsystems healthy',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final (label, ok, icon) in entries)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: '$label: ${ok ? 'ok' : 'down'}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: ok ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ok
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _storageStatusOk(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';
    if (status.isNotEmpty) return status == 'ok' || status == 'healthy';
    return data.values.any((v) => v?.toString() == 'ok');
  }

  bool _federationStatusOk(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';
    if (status.isNotEmpty) return status == 'ok' || status == 'healthy';
    return data.values.any((v) => v?.toString() == 'ok');
  }

  Widget _serverCard(BuildContext context) {
    if (_loading && _health == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null && _health == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
              const SizedBox(height: 8),
              LocalizedText(
                'Cannot reach backend',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              LocalizedText(
                _error!,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const LocalizedText('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final h = _health ?? {};
    final status = h['status']?.toString() ?? 'unknown';
    final isOk = status == 'ok';
    final revision = h['vcs_revision']?.toString() ?? '';
    final revisionShort = revision.length >= 12
        ? revision.substring(0, 12)
        : (revision.isEmpty ? '—' : revision);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOk ? Icons.check_circle : Icons.error,
                  color: isOk ? AppColors.success : AppColors.danger,
                  size: 32,
                ),
                const SizedBox(width: 12),
                LocalizedText(
                  'Backend Server',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                StatusChip(
                  label: status.toUpperCase(),
                  color: isOk ? AppColors.success : AppColors.danger,
                  icon: isOk ? Icons.check_circle : Icons.error,
                ),
              ],
            ),
            const Divider(),
            _row('Version', h['version']?.toString() ?? '—',
                localized: true),
            _row('Issuer', h['issuer']?.toString() ?? '—', localized: true),
            _row('Revision', revisionShort, localized: true),
            _row('Build Time', h['vcs_time']?.toString() ?? '—',
                localized: true),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    String title,
    Map<String, dynamic> data,
    IconData icon,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: adminModuleIconColor(AdminModuleId.health),
              ),
              const SizedBox(width: 8),
              LocalizedText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Divider(),
          if (data.isEmpty)
            const LocalizedText('No data available')
          else
            ...data.entries.map((e) => _row(e.key, e.value?.toString() ?? '—')),
        ],
      ),
    ),
  );

  Widget _debugCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 24,
                color: adminModuleIconColor(AdminModuleId.health),
              ),
              const SizedBox(width: 8),
              LocalizedText(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const LocalizedText('Audit Log'),
                onPressed: () => AdminRoute.go('audit-log'),
              ),
              ActionChip(
                label: const LocalizedText('Refresh Cache'),
                onPressed: () {
                  widget.api.clearCache();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: LocalizedText('Cache cleared')),
                  );
                },
              ),
              ActionChip(
                label: const LocalizedText('Test Connection'),
                onPressed: _refresh,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value, {bool localized = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              localized ? context.tr(label) : label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
}
