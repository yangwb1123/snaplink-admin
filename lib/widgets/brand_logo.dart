import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 品牌 logo（左上角）：品牌色渐变圆角块 + 盾牌图标。
///
/// 项目无静态图片资源时的品牌"图片"表达——品牌主题色渐变 + 图标，
/// 视觉上与 logo 图片一致；点击可打开抽屉（窄视口）。
///
/// R65：产品品牌标记的唯一实现。Portal/Admin 壳层头部、登录页缺省
/// 品牌区共用同一渐变/阴影/图标语言；[size]/[iconSize]/[radius] 允许
/// 缺省品牌区按登录卡尺寸调整，而品牌"形"始终来自这一处。
class BrandLogo extends StatelessWidget {
  /// 点击回调（窄视口打开抽屉）；null = 纯展示不可点。
  final VoidCallback? onTap;

  /// 方块边长（默认 32）。
  final double size;

  /// 盾牌图标尺寸（默认 18）。
  final double iconSize;

  /// 圆角半径（默认 8）。
  final double radius;

  const BrandLogo({
    super.key,
    this.onTap,
    this.size = 32,
    this.iconSize = 18,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
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
      child: Icon(
        Icons.shield_outlined,
        size: iconSize,
        color: Colors.white,
      ),
    );
    if (onTap == null) return logo;
    return Tooltip(
      message: 'Snaplink Admin',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: logo,
      ),
    );
  }
}
