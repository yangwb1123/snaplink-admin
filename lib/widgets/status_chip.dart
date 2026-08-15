import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 状态徽章：彩色圆角 chip（状态 = 颜色 + 文字，双表达）。
/// 替换散落的裸 Text 状态显示——视觉一致 + 可访问（不只靠颜色）。
class StatusChip extends StatelessWidget {
  /// 状态文案（i18n 键，工厂默认值为英文目录键）。
  final String label;

  /// 语义色（AppColors/主题色，仅作底色 alpha 混合来源）。
  final Color color;

  /// 状态图标；null = 纯文字徽章。
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  /// 常用状态工厂。
  factory StatusChip.active({String label = 'Active'}) => StatusChip(
    label: label,
    color: AppColors.success,
    icon: Icons.check_circle,
  );

  factory StatusChip.inactive({String label = 'Inactive'}) => StatusChip(
    label: label,
    color: AppColors.muted,
    icon: Icons.circle_outlined,
  );

  factory StatusChip.suspended({String label = 'Suspended'}) => StatusChip(
    label: label,
    color: AppColors.warning,
    icon: Icons.pause_circle,
  );

  factory StatusChip.healthy({String label = 'Healthy'}) =>
      StatusChip(label: label, color: AppColors.success, icon: Icons.favorite);

  factory StatusChip.unhealthy({String label = 'Unhealthy'}) =>
      StatusChip(label: label, color: AppColors.danger, icon: Icons.error);

  factory StatusChip.pending({String label = 'Pending'}) => StatusChip(
    label: label,
    color: AppColors.warning,
    icon: Icons.hourglass_top,
  );

  factory StatusChip.failed({String label = 'Failed'}) =>
      StatusChip(label: label, color: AppColors.danger, icon: Icons.error);

  factory StatusChip.degraded({String label = 'Degraded'}) => StatusChip(
    label: label,
    color: AppColors.warning,
    icon: Icons.warning_amber,
  );

  factory StatusChip.info({String label = 'Info'}) => StatusChip(
    label: label,
    color: AppColors.accentBlue,
    icon: Icons.info_outline,
  );

  factory StatusChip.unknown({String label = 'Unknown'}) => StatusChip(
    label: label,
    color: AppColors.muted,
    icon: Icons.help_outline,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    // 徽章底 = 语义色 alpha 叠表面；文字色按徽章底实际亮度选择（黑/白）。
    // 浅色下语义色 alpha 底接近白色 → 深色文字；深色下底变暗 → 白色文字。
    final alpha = isDark ? 0.22 : 0.14;
    final background = Color.alphaBlend(
      color.withValues(alpha: alpha),
      scheme.surface,
    );
    final onColor = background.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    // 图标点缀色：深色下用同族 400 提亮变体（R29，danger/warning 原色
    // 2.26-2.83:1 <3 非文本门限，提亮后 5.29-8.76:1 ≥AA）；浅色保持原色。
    final accent = isDark
        ? AppColors.semanticFor(Brightness.dark, color)
        : color;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: 0.85 + 0.15 * value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: accent),
              const SizedBox(width: 4),
            ],
            // 窄约束（375px 手机视口 Wrap 行）下省略号收敛，不溢出；
            // 无约束时自然宽度渲染，桌面像素不变（R6-c 筛选/页头换行）。
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
