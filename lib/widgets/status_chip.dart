import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 状态徽章：彩色圆角 chip（状态 = 颜色 + 文字，双表达）。
/// 替换散落的裸 Text 状态显示——视觉一致 + 可访问（不只靠颜色）。
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  /// 常用状态工厂。
  factory StatusChip.active({String label = 'Active'}) =>
      StatusChip(label: label, color: AppColors.success, icon: Icons.check_circle);

  factory StatusChip.inactive({String label = 'Inactive'}) =>
      StatusChip(label: label, color: AppColors.muted, icon: Icons.circle_outlined);

  factory StatusChip.suspended({String label = 'Suspended'}) =>
      StatusChip(label: label, color: AppColors.warning, icon: Icons.pause_circle);

  factory StatusChip.healthy({String label = 'Healthy'}) =>
      StatusChip(label: label, color: AppColors.success, icon: Icons.favorite);

  factory StatusChip.unhealthy({String label = 'Unhealthy'}) =>
      StatusChip(label: label, color: AppColors.danger, icon: Icons.error);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor = color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.brightness == Brightness.dark ? color : onColor,
            ),
          ),
        ],
      ),
    );
  }
}
