import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';

part 'break_glass_request_card_view.dart';

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
  Widget build(BuildContext context) => _buildRequestCard(context);
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
              width: 260, // R52：多段明细（原因/发起人/范围）两行省略，260 才不挤。
              cardDetail: true,
              builder: (_, i) {
                final session = sessions[i];
                final reason = session['reason']?.toString() ?? '';
                final createdBy = session['created_by']?.toString() ?? '';
                final scope = session['scope']?.toString() ?? 'readonly';
                return TableCellText(
                  [
                    if (reason.isNotEmpty) reason,
                    'by $createdBy · scope: $scope',
                  ].join('\n'),
                  muted: true,
                  maxLines: 2,
                );
              },
            ),
            AdminDataColumn(
              id: 'id',
              label: 'ID',
              width: 180,
              cardDetail: true,
              builder: (_, i) => CopyableCell(
                text: sessions[i]['id']?.toString() ?? '',
                contextProvider: () => context,
              ),
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
                return Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      runSpacing: 0,
                      children: [
                        if (pending)
                          TextButton(
                            onPressed: mutating ? null : () => onApprove(id),
                            child: const LocalizedText('Approve'),
                          ),
                        if (active)
                          TextButton(
                            onPressed: mutating
                                ? null
                                : () => onImpersonate(id),
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
                    ),
                  ),
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
    'approved' => StatusChip.active(label: 'Approved'),
    'active' => StatusChip.active(label: 'Active'),
    'revoked' => StatusChip.inactive(label: 'Revoked'),
    'expired' => StatusChip.inactive(label: 'Expired'),
    'rejected' => StatusChip.failed(label: 'Rejected'),
    _ => StatusChip.unknown(label: status),
  };
}
