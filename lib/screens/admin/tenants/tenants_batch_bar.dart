import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/batch_action_bar.dart';

/// 租户批量操作栏：已选数量 + 批量挂起/激活 + 退出选择。
///
/// 从 tenants_tab 拆出：图标用租户组强调色（由页面 [_accent] 传入）；
/// 确认弹窗与结果汇总语义保留在页面 [_batchSetStatus]。
class TenantsBatchBar extends StatelessWidget {
  final int selectedCount;
  final Color accent;
  final VoidCallback onSuspend;
  final VoidCallback onActivate;
  final VoidCallback onClearSelection;

  const TenantsBatchBar({
    super.key,
    required this.selectedCount,
    required this.accent,
    required this.onSuspend,
    required this.onActivate,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return BatchActionBar(
      selectedCount: selectedCount,
      accent: accent,
      actions: [
        BatchAction(
          label: 'Suspend',
          icon: Icons.pause_circle_outline,
          onPressed: onSuspend,
        ),
        BatchAction(
          label: 'Activate',
          icon: Icons.play_circle_outline,
          onPressed: onActivate,
        ),
      ],
      onClearSelection: onClearSelection,
    );
  }
}
