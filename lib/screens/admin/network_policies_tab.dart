import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';

import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'network_policy_dialog.dart';

/// Advertised network-boundary policies and classifier diagnostics.
class NetworkPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const NetworkPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<NetworkPoliciesTab> createState() => _NetworkPoliciesTabState();
}

class _NetworkPoliciesTabState extends State<NetworkPoliciesTab> {
  static const _basePath = '/api/v1/netpolicy/policies';
  static const _classifyPath = '/api/v1/netpolicy/classify';

  final _remoteCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  List<Map<String, dynamic>> _policies = const [];
  Map<String, dynamic>? _classification;
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.networkPolicies);

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_basePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_basePath);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remoteCtrl.dispose();
    _hostCtrl.dispose();
    super.dispose();
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
        _basePath,
        onRefresh: _applyRefresh,
      );
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _applyPolicies(data);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted && seq == _reqSeq) setState(() => _error = error.toString());
    } finally {
      if (mounted && seq == _reqSeq) setState(() => _loading = false);
    }
  }

  /// 缓存先渲染：命中时立即展示缓存行，后台刷新到位后再次渲染（R2）。
  void _applyPolicies(Map<String, dynamic> data) {
    final values = data['policies'] as List? ?? const [];
    _policies = values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  void _applyRefresh(Map<String, dynamic> fresh) {
    if (!mounted) return;
    setState(() => _applyPolicies(fresh));
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final draft = await showDialog<NetworkPolicyDraft>(
      context: context,
      builder: (_) => NetworkPolicyDialog(existing: existing),
    );
    if (draft == null || !mounted) return;
    await _write(
      () => widget.api.post(_basePath, draft.toJson()),
      existing == null ? 'Network policy created.' : 'Network policy updated.',
    );
  }

  Future<void> _delete(Map<String, dynamic> policy) async {
    final name = policy['name']?.toString() ?? '';
    if (name.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete network policy?',
      // X1 合规：动态值走 `{name}` 模板 + args，key 进入 zh 目录。
      message: context.tr(
        'Delete {name}? Requests will immediately fall through to the next matching policy.',
        {'name': name},
      ),
      confirmLabel: 'Delete policy',
      destructive: true,
      confirmText: name,
    );
    if (!confirmed) return;
    await _write(
      () => widget.api.delete('$_basePath/${Uri.encodeComponent(name)}'),
      'Network policy deleted.',
    );
  }

  Future<void> _classify() async {
    final remote = _remoteCtrl.text.trim();
    if (remote.isEmpty) {
      setState(() => _error = 'Enter a remote address to classify.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _classification = null;
    });
    try {
      final data = await widget.api.get(
        _classifyPath,
        query: {
          'remote_addr': remote,
          if (_hostCtrl.text.trim().isNotEmpty) 'host': _hostCtrl.text.trim(),
        },
      );
      if (mounted) setState(() => _classification = data);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() operation,
    String success,
  ) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText(success));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
          title: AppStrings.of(context).networkPolicies,
          onRefresh: _load,
          subtitle:
              'Map trusted CIDRs and hostnames to advertised endpoints. '
              'Higher priority wins; hostname matches win over CIDRs.',
          actions: [
            FilledButton.icon(
              onPressed: _mutating ? null : _edit,
              icon: const Icon(Icons.add, size: 18),
              label: const LocalizedText('Add policy'),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _loading || _mutating ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        AsyncView<List<Map<String, dynamic>>>(
          loading: _loading,
          error: _error,
          data: _policies,
          onRetry: _load,
          useSkeleton: true, skeletonDelay: const Duration(milliseconds: 150),
          emptyTitle: 'No network policies',
          emptySubtitle: 'Unclassified requests use the deployment defaults.',
          emptyActionLabel: 'Add policy',
          onEmptyAction: _edit,
          dataBuilder: (policies) => _policiesCard(context, policies),
        ),
        _classifierCard(context),
      ],
    );
  }

  /// 策略列表卡：组色图标 + SectionHeader（含策略数）+ AdminDataTable(compact)。
  Widget _policiesCard(
    BuildContext context,
    List<Map<String, dynamic>> policies,
  ) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.policy_outlined, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader(
                    'Network policies',
                    count: policies.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminDataTable(
              density: TableDensity.compact,
              minWidth: 760,
              columns: [
                AdminDataColumn(
                  id: 'name',
                  label: 'Policy'.localized,
                  width: 200,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    policies[i]['name']?.toString() ?? '',
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'priority',
                  label: 'Priority'.localized,
                  builder: (_, i) => TableCellText(
                    '${policies[i]['priority'] ?? 0}',
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'cidrs',
                  label: 'CIDRs'.localized,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    (policies[i]['cidrs'] as List? ?? const []).join(', '),
                    muted: true,
                    maxLines: 2,
                  ),
                ),
                AdminDataColumn(
                  id: 'hosts',
                  label: 'Hosts'.localized,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    (policies[i]['hostnames'] as List? ?? const []).join(
                      ', ',
                    ),
                    muted: true,
                    maxLines: 2,
                  ),
                ),
                AdminDataColumn(
                  id: 'actions',
                  label: '',
                  width: 90,
                  builder: (_, i) => IconButton(
                    onPressed: _mutating ? null : () => _delete(policies[i]),
                    icon: Icon(Icons.delete_outline, color: _accent),
                    tooltip: 'Delete'.localized,
                  ),
                ),
              ],
              itemCount: policies.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
              onRowTap: (i) => _edit(policies[i]),
            ),
          ],
        ),
      ),
    );
  }

  /// 分类器卡：组色图标 + SectionHeader + 输入 + 诊断结果。
  Widget _classifierCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.network_check, size: 20, color: _accent),
                const SizedBox(width: 8),
                const Expanded(child: SectionHeader('Policy classifier')),
              ],
            ),
            const SizedBox(height: 4),
            const LocalizedText(
              'Test a network tuple before changing edge routing.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remoteCtrl,
              decoration: InputDecoration(
                labelText: 'Remote address'.localized,
                hintText: '10.0.0.5:54321'.localized,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hostCtrl,
              decoration: InputDecoration(
                labelText: 'Host (optional)'.localized,
                hintText: 'api.internal.example.com'.localized,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _classify,
              child: const LocalizedText('Classify request'),
            ),
            if (_classification != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(_classification),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
