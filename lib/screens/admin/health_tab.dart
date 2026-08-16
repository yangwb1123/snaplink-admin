import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';
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

  /// 模块组色（overview → sky）：页头与卡片图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.health);

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

  /// 子系统健康判定：显式 `status` 字段优先，否则任一值为 'ok' 视为健康。
  bool _statusOk(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';
    if (status.isNotEmpty) return status == 'ok' || status == 'healthy';
    return data.values.any((v) => v?.toString() == 'ok');
  }

  @override
  Widget build(BuildContext context) {
    final hasData =
        _health?.isNotEmpty == true ||
        _storageHealth?.isNotEmpty == true ||
        _federationHealth?.isNotEmpty == true;
    return PullToRefresh(onRefresh: _refresh, child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        _header(context),
        // 健康总览（异常优先）：三个子系统状态一眼可见。
        _overview(context),
        const SizedBox(height: 12),
        // 三态：loading → 骨架；error → 卡片 + Retry；empty → EmptyState。
        if (_loading && _health == null)
          const SkeletonListTile(
            itemCount: 3,
            variant: SkeletonVariant.card,
            delay: Duration(milliseconds: 150),
          )
        else if (_error != null && _health == null)
          _errorCard(context)
        else if (!hasData)
          const EmptyState(
            variant: EmptyStateVariant.empty,
            title: 'No health data returned by the server yet.',
          )
        else ...[
          _serverCard(context),
          const SizedBox(height: 12),
          DistributedClusterPanel(api: widget.api),
          if (_storageHealth?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            _dataCard(
              context,
              'Storage Health',
              _storageHealth!,
              Icons.storage_outlined,
            ),
          ],
          if (_federationHealth?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            _dataCard(
              context,
              'Federation Health',
              _federationHealth!,
              Icons.lan_outlined,
            ),
          ],
        ],
        const SizedBox(height: 12),
        _actionsCard(context),
      ],
    ));
  }

  /// 页头：模块组色图标 + 标题 + 副标题 + 刷新（X7）。
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.monitor_heart_outlined, color: _accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: LocalizedText(
                    'System Health',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                LocalizedText(
                  'Health checks aggregate runtime reachability of the server, storage and cluster.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh'.localized,
          ),
        ],
      ),
    );
  }

  /// 健康总览：子系统状态徽章组（StatusChip 双编码 + 异常优先）。
  Widget _overview(BuildContext context) {
    final serverOk = _health?['status']?.toString() == 'ok';
    final storageOk =
        _storageHealth?.isNotEmpty == true && _statusOk(_storageHealth!);
    final federationOk =
        _federationHealth?.isNotEmpty == true && _statusOk(_federationHealth!);
    final anyDown = !serverOk || !storageOk || !federationOk;
    final icon = anyDown
        ? Icons.warning_amber_outlined
        : Icons.verified_user_outlined;
    final title = anyDown
        ? 'A subsystem needs attention'
        : 'All subsystems healthy';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: anyDown ? AppColors.warning : AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: LocalizedText(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge('Server', serverOk),
                _badge('Storage', storageOk),
                _badge('Federation', federationOk),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 状态徽章：语义色 + 状态图标（双编码，X9）。
  Widget _statusChip(bool ok, String label) => StatusChip(
    label: label,
    color: ok ? AppColors.success : AppColors.danger,
    icon: ok ? Icons.check_circle : Icons.error,
  );

  /// 总览徽章：子系统名 + ok/down 详情提示。
  Widget _badge(String label, bool ok) => Tooltip(
    message: '$label: ${ok ? 'ok' : 'down'}',
    child: _statusChip(ok, context.tr(label)),
  );

  /// 错误区：统一 ErrorStateCard（标题 + 明细 + Retry）；错误文本动态 Text（FM-1）。
  Widget _errorCard(BuildContext context) => ErrorStateCard(
    title: 'Cannot reach backend',
    message: _error ?? '',
    onRetry: _refresh,
  );

  /// 服务器卡片：状态徽章（状态值 verbatim，X10）+ 版本信息。
  Widget _serverCard(BuildContext context) {
    final h = _health ?? const <String, dynamic>{};
    final status = h['status']?.toString() ?? 'unknown';
    final isOk = status == 'ok';
    final revision = h['vcs_revision']?.toString() ?? '';
    final revisionShort = revision.length >= 12
        ? revision.substring(0, 12)
        : (revision.isEmpty ? '—' : revision);
    return _cardShell(
      context,
      icon: Icons.dns_outlined,
      title: 'Backend Server',
      trailing: _statusChip(isOk, status.toUpperCase()),
      children: [
        _row('Version', h['version']?.toString() ?? '—', localized: true),
        _row('Issuer', h['issuer']?.toString() ?? '—', localized: true),
        _row('Revision', revisionShort, localized: true),
        _row('Build Time', formatServerTime(h['vcs_time']), localized: true),
      ],
    );
  }

  /// 子系统数据卡：标题 + 健康徽章 + 键值行（键名 verbatim Text，X10）。
  Widget _dataCard(
    BuildContext context,
    String title,
    Map<String, dynamic> data,
    IconData icon,
  ) {
    final ok = _statusOk(data);
    return _cardShell(
      context,
      icon: icon,
      title: title,
      trailing: _statusChip(ok, context.tr(ok ? 'Healthy' : 'Unhealthy')),
      children: [
        if (data.isEmpty)
          const LocalizedText('No data available')
        else
          ...data.entries.map((e) => _row(e.key, e.value?.toString() ?? '—')),
      ],
    );
  }

  /// 快捷操作。
  Widget _actionsCard(BuildContext context) => _cardShell(
    context,
    icon: Icons.bolt_outlined,
    title: 'Quick Actions',
    children: [
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
              showAppSnackBar(context, content: LocalizedText('Cache cleared'));
            },
          ),
          ActionChip(
            label: const LocalizedText('Test Connection'),
            onPressed: _refresh,
          ),
        ],
      ),
    ],
  );

  /// 卡片壳：组色图标 + 标题 + 可选尾部徽章 + 内容（X7）。
  Widget _cardShell(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    required List<Widget> children,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: _accent),
              const SizedBox(width: 8),
              // R33：标题 Expanded（窄屏/字号缩放换行而非溢出），trailing 仍贴右。
              Expanded(
                child: LocalizedText(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const Divider(),
          ...children,
        ],
      ),
    ),
  );

  /// 键值行：字面量标签走 i18n（localized: true）；API 键/值 verbatim。
  Widget _row(String label, String value, {bool localized = false}) {
    final labelStyle = const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: localized
                ? LocalizedText(label, style: labelStyle)
                : Text(label, style: labelStyle),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
