import 'package:flutter/material.dart';

/// 设置分组卡片：多个 form 行 + 分隔线，替代"每个设置一张大卡片"。
///
/// 从 settings_screen.dart 拆出：布局纯 UI，不持有任何状态。
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: 32, // 对齐 label 起点（icon 20 + gap 12）
                  ),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 单行 form item：彩色图标 + 标签（可带描述）+ 控件，antd/el-form 风格。
class SettingsFormItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? description;
  final Widget control;

  const SettingsFormItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.control,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // R29 字体缩放：1.5x/2.0x 下控件（下拉/输入框/开关）与标签同排
          // 放不下（原 Row 溢出 6.8-211px）。窄容器或大字号时改为上下
          // 堆叠——控件独占一行、标签完整换行，不截断不溢出。
          // 1x 桌面（≥520）与测试视口（800×600）保持原 Row 布局不变。
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final stacked = constraints.maxWidth < 520 * scale;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: 12),
                    Expanded(child: labelCol),
                  ],
                ),
                const SizedBox(height: 12),
                // A fixed-width field (for example the native SSO origin)
                // must still obey the card's width when the row stacks.
                // Without this clamp it overflows the 320/400px layouts.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: control,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(child: labelCol),
              const SizedBox(width: 16),
              control,
            ],
          );
        },
      ),
    );
  }
}
