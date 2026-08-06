import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Responsive title and primary actions for admin collection pages.
class AdminListHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String createTooltip;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const AdminListHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.createTooltip,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(title),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
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
            ),
          ),
          // 主操作 = 带文字按钮（最高视觉等级）；次级 = 刷新图标。
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.tr(createTooltip)),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: context.strings.refresh,
          ),
        ],
      ),
    );
  }
}
