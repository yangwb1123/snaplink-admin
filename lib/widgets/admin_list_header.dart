import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/pressable_scale.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Responsive title and primary actions for admin collection pages.
///
/// 窄视口（<560）标题与操作区自动换行；默认动作区 = 创建按钮 + 刷新，
/// 传入 [actions] 时整体替换。标题/subtitle/按钮文案均为 i18n 键。
class AdminListHeader extends StatelessWidget {
  /// 页面标题（i18n 键）。
  final String title;

  /// 标题下副标题（i18n 键）；null = 不渲染。
  final String? subtitle;

  /// 创建按钮文案（i18n 键）。
  final String createTooltip;

  /// 创建动作；null = 不渲染创建按钮。
  final VoidCallback? onCreate;

  /// 刷新动作（始终渲染刷新图标）。
  final VoidCallback onRefresh;

  /// 额外操作区（替换默认的创建按钮 + 刷新按钮，例如无创建操作的页面）。
  final List<Widget>? actions;

  const AdminListHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.createTooltip = '',
    this.onCreate,
    required this.onRefresh,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            context.tr(title),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            context.tr(subtitle!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final actionWidgets = actions != null
        ? actions!
        : [
            // 主操作 = 带文字按钮（最高视觉等级）；次级 = 刷新图标。
            if (onCreate != null) ...[
              PressableScale(
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.tr(createTooltip)),
                ),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: context.strings.refresh,
            ),
          ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 窄视口：标题行 + 操作区换行；≥560 保持单行 Row。
          if (constraints.maxWidth < 560) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: double.infinity, child: titleColumn),
                ...actionWidgets,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleColumn),
              ...actionWidgets,
            ],
          );
        },
      ),
    );
  }
}
