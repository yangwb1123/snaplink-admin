import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 品牌 logo（左上角）：品牌色渐变圆角块 + 盾牌图标。
///
/// 项目无静态图片资源时的品牌"图片"表达——品牌主题色渐变 + 图标，
/// 视觉上与 logo 图片一致；点击可打开抽屉（窄视口）。
class BrandLogo extends StatelessWidget {
  /// 点击回调（窄视口打开抽屉）；null = 纯展示不可点。
  final VoidCallback? onTap;

  /// 方块边长（默认 32）。
  final double size;

  const BrandLogo({super.key, this.onTap, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.violet],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_outlined,
        size: 18,
        color: Colors.white,
      ),
    );
    if (onTap == null) return logo;
    return Tooltip(
      message: 'Snaplink Admin',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: logo,
      ),
    );
  }
}
