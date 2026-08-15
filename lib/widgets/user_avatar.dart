import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 首字母头像（Linear/GitHub 风格）：按名字稳定取色 + 首字母。
///
/// 颜色由名字 hash 决定（同名字同色），无需后端头像 URL。
class UserAvatar extends StatelessWidget {
  /// 用户名（首字母 + 稳定取色依据）。
  final String name;

  /// 头像半径（默认 18）。
  final double radius;

  const UserAvatar({super.key, required this.name, this.radius = 18});

  static const _palette = [
    AppColors.primary,
    AppColors.accentBlue,
    AppColors.success,
    AppColors.warning,
    AppColors.danger,
    AppColors.violet,
    AppColors.cyan,
    AppColors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final color = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.14),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
