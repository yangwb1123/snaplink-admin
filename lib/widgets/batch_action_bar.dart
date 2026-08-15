import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';

/// 批量操作栏中的单个动作（label 为 i18n 源键，栏内按当前 locale 渲染）。
///
/// 双/多动作语义（approve/reject、suspend/activate、delete 等）统一由
/// [BatchActionBar.actions] 承载；页面保留各自的确认弹窗语义。
class BatchAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// 破坏性动作（删除等）：图标与标签用错误色；否则用模块强调色。
  final bool destructive;

  const BatchAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });
}

/// 批量操作浮动栏：已选数量 + 动作列表 + 退出选择。
///
/// 管理端四个列表页（clients / local-users / tenants / users）此前各自
/// 内联或半共享此栏——统一为动作列表 API 后四处行为一致；图标强调色
/// 由页面传入模块组色（adminModuleIconColor），缺省回退主题 primary。
class BatchActionBar extends StatelessWidget {
  final int selectedCount;
  final List<BatchAction> actions;
  final VoidCallback onClearSelection;
  final bool isLoading;

  /// 模块强调色（页面传入 adminModuleIconColor）；null 时回退主题 primary。
  final Color? accent;

  const BatchActionBar({
    super.key,
    required this.selectedCount,
    required this.actions,
    required this.onClearSelection,
    this.isLoading = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final accentColor = accent ?? theme.colorScheme.primary;

    // 栏内容（计数 + 动作 + 退出选择）构建一次，宽/窄屏共用。
    final leading = [
      Icon(Icons.checklist, size: 20, color: accentColor),
      const SizedBox(width: 8),
      Text(
        context.tr('{count} selected', {'count': selectedCount}),
        style: theme.textTheme.titleSmall,
      ),
    ];
    final trailing = [
      for (final action in actions) ...[
        TextButton.icon(
          onPressed: isLoading ? null : action.onPressed,
          icon: Icon(
            action.icon,
            size: 18,
            color: action.destructive
                ? theme.colorScheme.error
                : accentColor,
          ),
          label: Text(context.tr(action.label)),
          style: action.destructive
              ? TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                )
              : null,
        ),
        const SizedBox(width: 4),
      ],
      IconButton(
        tooltip: 'Clear selection'.localized,
        icon: const Icon(Icons.close, size: 18),
        onPressed: isLoading ? null : onClearSelection,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      // 窄屏（375px 手机视口）换行不溢出；宽屏保持原有 Spacer 右对齐。
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 480) {
            return Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [...leading, ...trailing],
            );
          }
          return Row(
            children: [...leading, const Spacer(), ...trailing],
          );
        },
      ),
    );
  }
}
