import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/sensitive_data.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/staggered_fade_in.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'change_approval_models.dart';

/// 变更审批状态（后端规范 02：状态集中定义，防散落字符串漂移）。
abstract final class ChangeStatus {
  static const all = 'all';
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

/// 双人审批队列：高影响变更须由与提议者不同的管理员批准后才可应用，
/// 拒绝的变更永不应用。审批/拒绝均需输入变更 ID 二次确认（语义不变）。
class ChangeApprovalsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const ChangeApprovalsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<ChangeApprovalsTab> createState() => _ChangeApprovalsTabState();
}

class _ChangeApprovalsTabState extends State<ChangeApprovalsTab> {
  static const _basePath = '/api/v1/admin/changes';

  List<Map<String, dynamic>> _changes = const [];
  String _status = ChangeStatus.all;
  String? _error;
  bool _loading = false;
  bool _mutating = false;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.changeApprovals);

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_basePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_basePath);

  List<Map<String, dynamic>> get _visible => _status == ChangeStatus.all
      ? _changes
      : _changes
            .where((change) => change['status']?.toString() == _status)
            .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_available) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getStaleWhileRevalidate(
        _basePath,
        onRefresh: _applyRefresh,
      );
      if (!mounted) return;
      setState(() {
        _applyChanges(data);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 缓存先渲染：命中时立即展示缓存行，后台刷新到位后再次渲染（R2）。
  void _applyChanges(Map<String, dynamic> data) {
    final values = data['changes'] as List? ?? const [];
    _changes = values
        .whereType<Map>()
        .map(normalizeChangeApproval)
        .toList(growable: false);
  }

  void _applyRefresh(Map<String, dynamic> fresh) {
    if (!mounted) return;
    setState(() => _applyChanges(fresh));
  }

  Future<void> _propose() async {
    final draft = await showDialog<ChangeApprovalDraft>(
      context: context,
      builder: (_) => const ChangeApprovalProposalDialog(),
    );
    if (draft == null || !mounted) return;
    await _write(
      () => widget.api.post(_basePath, draft.body),
      'Change proposed for second-admin approval.',
    );
  }

  Future<void> _decide(Map<String, dynamic> change, bool approve) async {
    final id = change['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final action = approve ? 'approve' : 'reject';
    final actionName = change['action_type']?.toString() ?? 'this request';
    final confirmed = await ConfirmDialog.show(
      context,
      title: approve ? 'Approve this change?' : 'Reject this change?',
      message: approve
          ? context.tr(
              'Approval may immediately apply {action}. You must be a different administrator from the proposer.',
              {'action': actionName},
            )
          : context.tr(
              'Reject {action}? It will never be applied.',
              {'action': actionName},
            ),
      confirmLabel: approve ? 'Approve' : 'Reject',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    await _write(
      () => widget.api.post(
        '$_basePath/${Uri.encodeComponent(id)}/$action',
        {},
      ),
      approve ? 'Change approved.' : 'Change rejected.',
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LocalizedText(success)),
      );
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
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'Two-person administrative approvals are not enabled.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).changeApprovals,
          subtitle:
              'High-impact changes require an independent administrator to approve them before application.',
          onRefresh: _load,
          actions: [
            FilledButton.icon(
              onPressed: _mutating ? null : _propose,
              icon: const Icon(Icons.add_task, size: 18),
              label: const LocalizedText('Propose change'),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        _statusFilter(context),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (!_loading && _error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
          ),
        if (!_loading && _error == null && _visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: EmptyState(
              compact: true,
              variant: _status == ChangeStatus.all
                  ? EmptyStateVariant.empty
                  : EmptyStateVariant.noMatch,
              title: 'No change requests',
              subtitle: _status == ChangeStatus.all
                  ? 'No governed changes have been proposed.'
                  : 'No requests currently have this status.',
              actionLabel: _status == ChangeStatus.all ? null : 'Clear filter',
              actionIcon: Icons.filter_alt_off,
              onAction: _status == ChangeStatus.all
                  ? null
                  : () => setState(() => _status = ChangeStatus.all),
            ),
          ),
        if (!_loading && _error == null && _visible.isNotEmpty)
          _changeList(context),
      ],
    );
  }

  /// 状态过滤：常量状态值走 i18n 键（all/pending/approved/applied/rejected/failed）。
  Widget _statusFilter(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final status in const [
          ChangeStatus.all,
          ChangeStatus.pending,
          ChangeStatus.approved,
          'applied',
          ChangeStatus.rejected,
          'failed',
        ])
          ChoiceChip(
            label: LocalizedText(status),
            selected: _status == status,
            onSelected: (_) => setState(() => _status = status),
          ),
      ],
    ),
  );

  /// 审批队列：SectionHeader（计数）+ 变更卡片（ExpansionTile 展开详情）。
  Widget _changeList(BuildContext context) {
    final changes = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SectionHeader('Change requests', count: changes.length),
        ),
        const SizedBox(height: 4),
        for (final (index, change) in changes.indexed)
          StaggeredFadeIn(index: index, child: _changeCard(context, change)),
      ],
    );
  }

  /// 变更卡片：动作类型 + StatusChip（双表达）；展开显示 payload JSON /
  /// 失败原因 / 决策元数据；pending 变更提供 批准/拒绝（type-to-confirm）。
  Widget _changeCard(BuildContext context, Map<String, dynamic> change) {
    final status = change['status']?.toString() ?? 'unknown';
    final pending = status == ChangeStatus.pending;
    final decidedBy = change['approved_by']?.toString().trim() ?? '';
    final action = change['action_type']?.toString() ?? 'Change request';
    final proposedBy = change['proposed_by']?.toString() ?? 'unknown';
    final reason = change['reason']?.toString() ?? '';
    final createdAt = change['created_at']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(Icons.task_alt_outlined, size: 20, color: _accent),
        title: Row(
          children: [
            Expanded(child: Text(action)),
            _statusChip(context, status),
          ],
        ),
        subtitle: Text(
          [
            if (reason.isNotEmpty) reason,
            context.tr('Proposed by {user}', {'user': proposedBy}),
          ].join('\n'),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(
              SensitiveData.redact(
                change['payload'] ?? const <String, dynamic>{},
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          if (change['failure_note']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              change['failure_note'].toString(),
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            [
              if (createdAt.isNotEmpty)
                context.tr('Created {date}', {'date': createdAt}),
              if (decidedBy.isNotEmpty)
                context.tr('Decided by {user}', {'user': decidedBy}),
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (pending) ...[
            const SizedBox(height: 12),
            OverflowBar(
              children: [
                OutlinedButton(
                  onPressed: _mutating ? null : () => _decide(change, false),
                  child: const LocalizedText('Reject'),
                ),
                FilledButton(
                  onPressed: _mutating ? null : () => _decide(change, true),
                  child: const LocalizedText('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 状态双表达：pending/approved/applied/rejected/failed 用语义工厂；
  /// 未知值原样展示（API 值走 Text，X10 不伪造 i18n 键）。
  Widget _statusChip(BuildContext context, String status) => switch (status) {
    'pending' => StatusChip.pending(label: context.tr('Pending')),
    'approved' => StatusChip.active(label: context.tr('Approved')),
    'applied' => StatusChip.active(label: context.tr('Applied')),
    'rejected' => StatusChip.failed(label: context.tr('Rejected')),
    'failed' => StatusChip.failed(label: context.tr('Failed')),
    _ => StatusChip.unknown(
        label: status.isEmpty ? context.tr('unknown') : status,
      ),
  };
}

