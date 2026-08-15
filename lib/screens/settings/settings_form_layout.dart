import 'package:flutter/material.dart';

/// 设置分组卡片：多个 form 行 + 分隔线，替代"每个设置一张大卡片"。
///
/// 从 settings_screen.dart 拆出：布局纯 UI，不持有任何状态。
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}
