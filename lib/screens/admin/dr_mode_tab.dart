import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// Disaster Recovery mode management tab.
/// URL: /admin/dr-mode
class DRModeTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const DRModeTab({super.key, required this.api, required this.capabilities});
  @override
  State<DRModeTab> createState() => _DRModeTabState();
}

class _DRModeTabState extends State<DRModeTab> {
  static const _path = '/api/v1/admin/dr/mode';

  /// 可选模式（normal 为恢复目标，其余按降级程度递增）。
  static const _modeIds = [
    'normal',
    'read_only',
    'auth_only',
    'local_only',
    'maintenance',
  ];

  final _reasonCtrl = TextEditingController();
  Map<String, dynamic>? _status;
  String _selectedMode = 'normal';
  String? _error; // 加载错误 → 带 Retry 的横幅（X4）
  String? _formError; // 校验/提交错误 → 表单内联提示
  bool _loading = false;
  bool _mutating = false;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.drMode);

  bool get _available => widget.capabilities.hasAnyPathPrefix(_path);

  String? get _currentMode => _status?['mode']?.toString();

  /// 模式描述（目录背书的静态文案，zh 均有翻译）。
  String _modeDescription(String mode) => switch (mode) {
    'normal' => 'All request classes are available.',
    'read_only' =>
        'Administrative writes are blocked; the token plane remains available.',
    'auth_only' =>
        'Only authentication, token, and discovery requests remain available.',
    'local_only' => 'Endpoints that depend on remote systems are shed.',
    'maintenance' => 'Every non-probe request is rejected.',
    _ => 'Unknown service posture.',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_available) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_path);
      if (!mounted) return;
      final mode = data['mode']?.toString() ?? 'normal';
      setState(() {
        _status = data.isEmpty ? null : data;
        _selectedMode = _modeIds.contains(mode) ? mode : 'normal';
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load DR mode status.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _applyMode() async {
    final current = _currentMode ?? 'normal';
    if (_selectedMode == current) return;
    final reason = _reasonCtrl.text.trim();
    if (_selectedMode != 'normal' && reason.isEmpty) {
      setState(() {
        _formError =
            'Add an incident or change reference before degrading service.';
      });
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: _selectedMode == 'normal'
          ? 'Return to normal service?'
          : 'Apply degraded-service mode?',
      message: context.tr(
        'Change the server from {current} to {selected}. {description}',
        {
          'current': current,
          'selected': _selectedMode,
          'description': context.tr(_modeDescription(_selectedMode)),
        },
      ),
      confirmLabel: 'Apply mode',
      destructive: _selectedMode != 'normal',
      confirmText: _selectedMode != 'normal' ? _selectedMode : null,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _formError = null;
    });
    try {
      await widget.api.post(_path, {
        'mode': _selectedMode,
        if (reason.isNotEmpty) 'reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            'Service mode changed to {mode}.',
            args: {'mode': _selectedMode},
          ),
        ),
      );
      _reasonCtrl.clear();
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _formError = e.toString());
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
          title: AppStrings.of(context).drMode,
          subtitle:
              'Disaster recovery modes let you serve authentication when the primary replica is unavailable.',
          onRefresh: _load,
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (!_loading && _error != null)
          _ErrorBanner(error: _error!, onRetry: _load),
        if (!_loading && _error == null && _status == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(
              compact: true,
              title: 'No DR mode status available.',
            ),
          ),
        if (!_loading && _error == null && _status != null)
          _statusCard(context),
      ],
    );
  }

  /// 状态卡：组色图标 + SectionHeader（当前模式 chip）+ 目标模式选择表单。
  Widget _statusCard(BuildContext context) {
    final mode = _currentMode ?? 'normal';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sync_problem, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader(
                    'Current service mode',
                    action: mode == 'normal'
                        ? StatusChip.active(label: context.tr('Normal'))
                        : StatusChip.degraded(label: context.tr('Degraded')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LocalizedText(
              'Current mode: {mode}',
              args: {'mode': mode},
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            LocalizedText(
              _modeDescription(mode),
              style: const TextStyle(color: AppColors.textSubtle),
            ),
            const Divider(height: 28),
            DropdownButtonFormField<String>(
              initialValue: _selectedMode,
              decoration: InputDecoration(
                labelText: 'Target service mode'.localized,
              ),
              items: [
                for (final id in _modeIds)
                  DropdownMenuItem(value: id, child: Text(id)),
              ],
              onChanged: _mutating
                  ? null
                  : (value) => setState(() {
                      _selectedMode = value!;
                      _formError = null;
                    }),
            ),
            const SizedBox(height: 12),
            LocalizedText(
              _modeDescription(_selectedMode),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSubtle,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              enabled: !_mutating,
              decoration: InputDecoration(
                labelText: 'Reason / incident reference'.localized,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _mutating ? null : _applyMode,
                icon: const Icon(Icons.policy_outlined, size: 18),
                label: const LocalizedText('Apply service mode'),
              ),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 12),
              LocalizedText(
                _formError!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 错误横幅（X4 模式）：图标 + 消息（API 值走 Text）+ Retry。
class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const LocalizedText('Retry')),
        ],
      ),
    ),
  );
}
