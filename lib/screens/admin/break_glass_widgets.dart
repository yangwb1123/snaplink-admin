import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';

/// 撤销文案（目录背书的固定文案 + 按 API 值渲染的结果摘要）。
abstract final class BreakGlassRevocationCopy {
  static const confirmation =
      'Revoke this emergency-access grant? Snaplink will report every derived '
      'session and token result. Failed items retain stable idempotency keys '
      'for reconciliation.';

  static ({String key, Map<String, Object?> args}) resultCopy(
    Map<String, dynamic> response,
  ) {
    final values = response['credential_results'];
    final results = values is List
        ? values.whereType<Map>().toList()
        : const <Map>[];
    final failed = results.where((item) => item['status'] != 'revoked').length;
    final revoked = results.length - failed;
    if (response['retryable'] == true || failed > 0) {
      return (
        key:
            'Grant revoked; {revoked} derived credentials were revoked and {failed} failed. Retry only the reported idempotency keys.',
        args: {'revoked': revoked, 'failed': failed},
      );
    }
    return (
      key: 'Grant and all {revoked} reported derived credentials were revoked.',
      args: {'revoked': revoked},
    );
  }
}

/// 新建 break-glass 请求的表单卡：组色图标 + SectionHeader，校验/提交错误
/// 内联展示（formError 与加载错误职责分离）。
class BreakGlassRequestCard extends StatefulWidget {
  final TextEditingController targetController;
  final TextEditingController reasonController;
  final String scope;
  final bool requireApproval;
  final bool mutating;

  /// 模块强调色（security 组 rose）。
  final Color accent;

  /// 校验/提交错误 → 表单内联提示。
  final String? formError;

  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String> onTtlChanged;
  final ValueChanged<bool> onRequireApprovalChanged;
  final VoidCallback onCreate;

  const BreakGlassRequestCard({
    super.key,
    required this.targetController,
    required this.reasonController,
    required this.scope,
    required this.requireApproval,
    required this.mutating,
    required this.accent,
    required this.formError,
    required this.onScopeChanged,
    required this.onTtlChanged,
    required this.onRequireApprovalChanged,
    required this.onCreate,
  });

  @override
  State<BreakGlassRequestCard> createState() => _BreakGlassRequestCardState();
}

class _BreakGlassRequestCardState extends State<BreakGlassRequestCard> {
  final _formKey = GlobalKey<FormState>();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) {
    final targetController = widget.targetController;
    final reasonController = widget.reasonController;
    final scope = widget.scope;
    final requireApproval = widget.requireApproval;
    final mutating = widget.mutating;
    final accent = widget.accent;
    final formError = widget.formError;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency_outlined, size: 20, color: accent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: SectionHeader('New break-glass request'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: targetController,
                enabled: !mutating,
                decoration: InputDecoration(
                  labelText: 'Target user ID'.localized,
                  hintText: 'user@example.com'.localized,
                  helperText:
                      'An existing user account; the request targets this identity.'
                          .localized,
                ),
                validator: (value) => targetController.text.trim().isEmpty
                    ? 'Target user and reason are required.'.localized
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                enabled: !mutating,
                decoration: InputDecoration(
                  labelText: 'Reason (ticket/incident ref)'.localized,
                  hintText: 'INC-12345'.localized,
                  helperText:
                      'Ticket or incident reference; required for traceability.'
                          .localized,
                ),
                maxLines: 2,
                validator: (value) =>
                    targetController.text.trim().isNotEmpty &&
                        reasonController.text.trim().isEmpty
                    ? 'Target user and reason are required.'.localized
                    : null,
              ),
              const SizedBox(height: 12),
              // R31：保持 Dropdown——Scope 三段标签（Impersonate 等）与下方
              // 授权列表的动作文案同词，SegmentedButton 常显会让既有测试的
              // find.text 语义歧义（且 grant 动作本身已是可见选择点）。
              DropdownButtonFormField<String>(
                initialValue: scope,
                // R29 字体缩放：isExpanded 约束选中项宽度，2x 下不横向溢出。
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Scope'.localized),
                items: const [
                  DropdownMenuItem(
                    value: 'readonly',
                    child: LocalizedText('Read-only'),
                  ),
                  DropdownMenuItem(
                    value: 'impersonate',
                    child: LocalizedText('Impersonate'),
                  ),
                  DropdownMenuItem(
                    value: 'escalate',
                    child: LocalizedText('Escalate'),
                  ),
                ],
                onChanged: mutating
                    ? null
                    : (value) => widget.onScopeChanged(value ?? 'readonly'),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !mutating,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'TTL (seconds, default 900)'.localized,
                  helperText:
                      'Session lifetime in seconds; the server enforces the maximum.'
                          .localized,
                ),
                onChanged: widget.onTtlChanged,
              ),
              // R31：二选一设置 → SwitchListTile（原 Checkbox 是开关语义，
              // Checkbox 应留给确认/多选场景）。
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LocalizedText('Require approval'),
                value: requireApproval,
                onChanged: mutating ? null : widget.onRequireApprovalChanged,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: mutating ? null : _submit,
                icon: mutating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 18),
                label: const LocalizedText('Create break-glass request'),
              ),
              if (formError != null) ...[
                const SizedBox(height: 12),
                LocalizedText(
                  formError,
                  // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                  style: TextStyle(
                    color: AppColors.semanticFor(
                      Theme.of(context).brightness,
                      AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 会话列表：SectionHeader（计数 + 组色刷新）+ loading/empty/table 三态，
/// 状态列用 StatusChip（颜色 + 文字双表达），行点击进入详情。
class BreakGlassSessionsList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final bool loading;
  final bool mutating;

  /// 模块强调色（security 组 rose）。
  final Color accent;

  final VoidCallback onRefresh;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onImpersonate;
  final ValueChanged<String> onRevoke;

  const BreakGlassSessionsList({
    super.key,
    required this.sessions,
    required this.loading,
    required this.mutating,
    required this.accent,
    required this.onRefresh,
    required this.onOpen,
    required this.onApprove,
    required this.onImpersonate,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(
        'Sessions',
        count: sessions.isEmpty ? null : sessions.length,
        action: IconButton(
          onPressed: loading ? null : onRefresh,
          icon: Icon(Icons.refresh, color: accent),
          tooltip: 'Refresh'.localized,
        ),
      ),
      if (loading) const SkeletonListTile(itemCount: 3),
      if (!loading && sessions.isEmpty)
        const EmptyState(compact: true, title: 'No break-glass sessions.'),
      if (!loading && sessions.isNotEmpty)
        AdminDataTable(
          minWidth: 920,
          density: TableDensity.compact,
          columns: [
            AdminDataColumn(
              id: 'session',
              label: 'Session',
              width: 220,
              cardPrimary: true,
              builder: (_, i) {
                final target =
                    sessions[i]['target_user_id']?.toString() ??
                    sessions[i]['target_user']?.toString() ??
                    '';
                final status = sessions[i]['status']?.toString() ?? 'unknown';
                return TableCellText('$target · $status', bold: true);
              },
            ),
            AdminDataColumn(
              id: 'status',
              label: 'Status',
              cardDetail: true, // R52：会话状态是卡片最重要细节（原先被漏）。
              builder: (_, i) => _sessionStatusChip(
                sessions[i]['status']?.toString() ?? 'unknown',
              ),
            ),
            AdminDataColumn(
              id: 'details',
              label: 'Details',
              width: 260, // R52：多段明细（原因/发起人/范围/ID）两行省略，260 才不挤。
              cardDetail: true,
              builder: (_, i) {
                final session = sessions[i];
                final id = session['id']?.toString() ?? '';
                final reason = session['reason']?.toString() ?? '';
                final createdBy = session['created_by']?.toString() ?? '';
                final scope = session['scope']?.toString() ?? 'readonly';
                return TableCellText(
                  [
                    if (reason.isNotEmpty) reason,
                    'by $createdBy · scope: $scope · $id',
                  ].join('\n'),
                  muted: true,
                  maxLines: 2,
                );
              },
            ),
            AdminDataColumn(
              id: 'actions',
              label: '',
              width: 360,
              builder: (_, i) {
                final id = sessions[i]['id']?.toString() ?? '';
                final status = sessions[i]['status']?.toString() ?? 'unknown';
                final pending = status == 'pending';
                final active = status == 'active';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pending)
                      TextButton(
                        onPressed: mutating ? null : () => onApprove(id),
                        child: const LocalizedText('Approve'),
                      ),
                    if (active)
                      TextButton(
                        onPressed: mutating ? null : () => onImpersonate(id),
                        child: const LocalizedText('Impersonate'),
                      ),
                    if (pending || active)
                      TextButton(
                        onPressed: mutating ? null : () => onRevoke(id),
                        style: TextButton.styleFrom(
                          // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                          foregroundColor: AppColors.semanticFor(
                            Theme.of(context).brightness,
                            AppColors.danger,
                          ),
                        ),
                        child: const LocalizedText('Revoke'),
                      ),
                  ],
                );
              },
            ),
          ],
          itemCount: sessions.length,
          rowBuilder: (_, _) => const SizedBox.shrink(),
          onRowTap: (i) => onOpen(sessions[i]['id']?.toString() ?? ''),
        ),
    ],
  );

  StatusChip _sessionStatusChip(String status) => switch (status) {
    'pending' => StatusChip.pending(label: 'Pending'),
    'active' => StatusChip.active(label: 'Active'),
    'revoked' => StatusChip.inactive(label: 'Revoked'),
    'expired' => StatusChip.inactive(label: 'Expired'),
    _ => StatusChip.unknown(label: status),
  };
}
