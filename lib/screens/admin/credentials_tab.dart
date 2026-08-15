import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';

/// Credential rotation inventory and compromise reporting tab.
/// URLs: /admin/credentials, /admin/credentials/report
class CredentialsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const CredentialsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<CredentialsTab> createState() => _CredentialsTabState();
}

class _CredentialsTabState extends State<CredentialsTab> {
  static const _credsPath = '/api/v1/admin/credentials';

  List<Map<String, dynamic>> _credentials = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;
  bool _showReportForm = false;
  final _typeCtrl = TextEditingController();
  late final void Function() _cancelPopState;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.credentials);

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_credsPath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_credsPath);

  /// 首个命中的字段值（兼容新旧字段命名；API 值一律走 Text，X1/X10）。
  String _value(int i, List<String> keys) {
    final map = _credentials[i];
    for (final key in keys) {
      final v = map[key];
      if (v != null) return v.toString();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
    if (_available) _load();
  }

  @override
  void dispose() {
    _cancelPopState();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    setState(() => _showReportForm = route.subresource == 'report');
  }

  Future<void> _load() async {
    if (!_available) return;
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getStaleWhileRevalidate(
        _credsPath,
        onRefresh: _applyRefresh,
      );
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _applyCredentials(data);
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = 'Could not load credentials.';
          _loading = false;
        });
      }
    }
  }

  /// 缓存先渲染：命中时立即展示缓存行，后台刷新到位后再次渲染（R2）。
  void _applyCredentials(Map<String, dynamic> data) {
    final items = data['credentials'] as List? ?? data['items'] as List? ?? [];
    _credentials = items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  void _applyRefresh(Map<String, dynamic> fresh) {
    if (!mounted) return;
    setState(() => _applyCredentials(fresh));
  }

  Future<void> _reportCompromise() async {
    final type = _typeCtrl.text.trim();
    // 泄露处理语义：凭据类型必填（门禁在提交前强制，测试依赖此文案）。
    if (type.isEmpty) {
      setState(() => _error = 'Enter a credential type.');
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Report compromise?',
      message: 'Report $type credentials as compromised?',
      confirmLabel: 'Report',
      destructive: true,
      confirmText: type,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.post(
        '/api/v1/admin/credentials/${Uri.encodeComponent(type)}/compromise',
      );
      if (!mounted) return;
      _typeCtrl.clear();
      showAppSnackBar(context, content: LocalizedText('Compromise reported.'));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).credentials,
          subtitle: 'Credential rotation inventory and compromise reporting.',
          onRefresh: _load,
          actions: [
            if (!_showReportForm)
              OutlinedButton.icon(
                onPressed: () =>
                    AdminRoute.go('credentials', subresource: 'report'),
                icon: Icon(Icons.warning_amber_outlined, size: 18, color: _accent),
                label: const LocalizedText('Report compromise'),
              ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        if (_showReportForm) _buildReportForm(context),
        if (!_loading && _error != null)
          ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (!_loading &&
            _error == null &&
            _credentials.isEmpty &&
            !_showReportForm)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(compact: true, title: 'No credentials found.'),
          ),
        if (!_loading && _error == null && _credentials.isNotEmpty)
          _credentialsCard(context),
      ],
    );
  }

  /// 凭据库存卡：组色钥匙图标 + SectionHeader（计数）+ AdminDataTable(compact)。
  Widget _credentialsCard(BuildContext context) {
    final credentials = _credentials;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key_outlined, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader(
                    AppStrings.of(context).credentials,
                    count: credentials.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminDataTable(
              density: TableDensity.compact,
              minWidth: 680,
              columns: [
                AdminDataColumn(
                  id: 'credential',
                  label: 'Credential'.localized,
                  width: 240,
                  cardPrimary: true,
                  builder: (_, i) {
                    final type = _value(i, ['type', 'credential_type']);
                    final id = _value(i, ['id']);
                    return TableCellText(
                      type.isEmpty ? id : '$type · $id',
                      level: DataEmphasisLevel.primary,
                    );
                  },
                ),
                AdminDataColumn(
                  id: 'status',
                  label: 'Status'.localized,
                  builder: (_, i) =>
                      _statusChip(context, _value(i, ['status'])),
                ),
                AdminDataColumn(
                  id: 'rotated',
                  label: 'Rotated'.localized,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    _value(i, ['rotated_at', 'last_rotated']).isEmpty
                        ? context.tr('never')
                        : _value(i, ['rotated_at', 'last_rotated']),
                    muted: true,
                    maxLines: 2,
                  ),
                ),
              ],
              itemCount: credentials.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// 状态双表达：active/compromised/expired/suspended 用语义工厂；未知值走 Text（X10）。
  Widget _statusChip(BuildContext context, String status) => switch (status) {
    'active' => StatusChip.active(label: context.tr('Active')),
    'compromised' => StatusChip.failed(label: context.tr('Compromised')),
    'expired' => StatusChip.degraded(label: context.tr('Expired')),
    'suspended' => StatusChip.suspended(label: context.tr('Suspended')),
    _ => StatusChip.unknown(
        label: status.isEmpty ? context.tr('unknown') : status,
      ),
  };

  Widget _buildReportForm(BuildContext context) => Card(
    color: AppColors.warning.withValues(alpha: 0.05),
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, size: 20, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: LocalizedText(
                  'Report credential compromise',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const LocalizedText(
            'Report a credential type as compromised to trigger rotation and '
            'containment across services.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _typeCtrl,
            decoration: InputDecoration(
              labelText: 'Credential type'.localized,
              hintText: 'client_secret, signing_key, etc.'.localized,
            ),
          ),
          const SizedBox(height: 12),
          OverflowBar(
            children: [
              OutlinedButton(
                onPressed: () => AdminRoute.go('credentials'),
                child: const LocalizedText('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _mutating ? null : _reportCompromise,
                child: const LocalizedText('Report compromise'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

