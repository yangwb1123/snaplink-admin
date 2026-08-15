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

/// Threat detection policy management tab.
/// URLs: /admin/threat-policies, /admin/threat-policies/new, /admin/threat-policies/{id}/edit
class ThreatPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const ThreatPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<ThreatPoliciesTab> createState() => _ThreatPoliciesTabState();
}

class _ThreatPoliciesTabState extends State<ThreatPoliciesTab> {
  static const _path = '/api/v1/admin/threat-policies';
  List<Map<String, dynamic>> _policies = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;
  late final void Function() _cancelPopState;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.threatPolicies);

  bool get _available => widget.capabilities.hasAnyPathPrefix(_path);

  @override
  void initState() {
    super.initState();
    _load();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  bool _editing = false;
  bool _creating = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  String? _editId;

  void _handleRoute() {
    final route = AdminRoute.current();
    _creating = route.isNew;
    _editing = route.isEdit;
    _editId = route.resourceId;
    if (_creating) {
      _nameCtrl.clear();
      _descCtrl.clear();
      _rulesCtrl.clear();
    }
    if (_editing && _editId != null) {
      final existing = _policies
          .where((p) => p['id']?.toString() == _editId)
          .firstOrNull;
      if (existing != null) {
        _nameCtrl.text = existing['name']?.toString() ?? '';
        _descCtrl.text = existing['description']?.toString() ?? '';
        _rulesCtrl.text =
            existing['rules']?.toString() ?? existing['config']?.toString() ?? '';
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cancelPopState();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _rulesCtrl.dispose();
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
      final data = await widget.api.get(_path);
      final items = data['policies'] as List? ?? [];
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _policies = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _handleRoute();
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted && seq == _reqSeq) setState(() { _error = e.toString(); _loading = false; });
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        setState(() { _error = 'Could not load threat policies.'; _loading = false; });
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a policy name.');
      return;
    }
    final body = {
      'name': name,
      'description': _descCtrl.text.trim(),
      'rules': _rulesCtrl.text.trim(),
    };
    setState(() => _mutating = true);
    try {
      final pathName = _editing && _editId != null ? _editId! : name;
      await widget.api.put('$_path/${Uri.encodeComponent(pathName)}', body);
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText(_editing ? 'Policy updated.' : 'Policy created.'));
      if (mounted) AdminRoute.go('threat-policies');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete policy?',
      message: 'Delete this threat policy?',
      confirmLabel: 'Delete',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete('$_path/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('Policy deleted.'));
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
    if (_creating || _editing) return _buildForm(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).threatPolicies,
          subtitle:
              'Realtime threat detection rules protecting authentication flows.',
          onRefresh: _load,
          actions: [
            FilledButton.icon(
              onPressed: () => AdminRoute.go('threat-policies', action: 'new'),
              icon: const Icon(Icons.add, size: 18),
              label: const LocalizedText('Add policy'),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        if (!_loading && _error != null)
          ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (!_loading && _error == null && _policies.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: EmptyState(
              compact: true,
              title: 'No threat policies configured.',
              actionLabel: 'Add policy',
              onAction: () => AdminRoute.go('threat-policies', action: 'new'),
            ),
          ),
        if (!_loading && _error == null && _policies.isNotEmpty)
          _policiesCard(context),
      ],
    );
  }

  /// 策略列表卡：组色盾牌图标 + SectionHeader（计数）+ AdminDataTable(compact)。
  Widget _policiesCard(BuildContext context) {
    final policies = _policies;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader(
                    AppStrings.of(context).threatPolicies,
                    count: policies.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminDataTable(
              density: TableDensity.compact,
              minWidth: 920,
              columns: [
                AdminDataColumn(
                  id: 'policy',
                  label: 'Policy'.localized,
                  width: 220,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    policies[i]['name']?.toString() ?? '',
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'description',
                  label: 'Description'.localized,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    policies[i]['description']?.toString() ?? '',
                    muted: true,
                    maxLines: 2,
                  ),
                ),
                AdminDataColumn(
                  id: 'id',
                  label: 'ID'.localized,
                  builder: (_, i) => CopyableCell(
                    text: policies[i]['id']?.toString() ?? '',
                    contextProvider: () => context,
                  ),
                ),
                AdminDataColumn(
                  id: 'status',
                  label: 'Status'.localized,
                  builder: (_, i) => policies[i]['enabled'] == true
                      ? StatusChip.active(label: 'Enabled')
                      : StatusChip.inactive(label: 'Disabled'),
                ),
                AdminDataColumn(
                  id: 'actions',
                  label: '',
                  width: 100,
                  builder: (_, i) => TextButton(
                    onPressed: _mutating
                        ? null
                        : () => _delete(policies[i]['name']?.toString() ?? ''),
                    style: TextButton.styleFrom(
                      // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                      foregroundColor: AppColors.semanticFor(
                        Theme.of(context).brightness,
                        AppColors.danger,
                      ),
                    ),
                    child: const LocalizedText('Delete'),
                  ),
                ),
              ],
              itemCount: policies.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
              onRowTap: (i) => AdminRoute.go(
                'threat-policies',
                resourceId: policies[i]['name']?.toString() ?? '',
                action: 'edit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      Row(
        children: [
          Icon(Icons.shield_outlined, size: 22, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: LocalizedText(
              _editing ? 'Edit policy' : 'Add policy',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Name'.localized)),
      const SizedBox(height: 12),
      TextField(
        controller: _descCtrl,
        decoration: InputDecoration(labelText: 'Description'.localized),
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _rulesCtrl,
        decoration: InputDecoration(labelText: 'Rules / Config'.localized),
        maxLines: 4,
      ),
      const SizedBox(height: 16),
      OverflowBar(
        children: [
          OutlinedButton(
            onPressed: () => AdminRoute.go('threat-policies'),
            child: const LocalizedText('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _mutating ? null : _save,
            child: LocalizedText(_editing ? 'Update' : 'Create'),
          ),
        ],
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LocalizedText(
            _error!,
            // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
            style: TextStyle(
              color: AppColors.semanticFor(
                Theme.of(context).brightness,
                AppColors.danger,
              ),
            ),
          ),
        ),
    ],
  );
}

