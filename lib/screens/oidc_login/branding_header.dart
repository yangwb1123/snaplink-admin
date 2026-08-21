import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// 租户品牌头：logo（网络图片）+ 名称，品牌色可覆盖。
///
/// 回退逻辑保持不变：无 logo 时只渲染名称；名称缺失时 logo 承担语义标签
/// （Organization logo），名称存在时 logo 视为装饰并从语义中排除；
/// logo 加载失败静默隐藏（SizedBox.shrink），不打断布局。
class BrandingHeader extends StatelessWidget {
  final String? brandLogoUrl;
  final String? brandName;
  final Color? brandColor;

  const BrandingHeader({
    super.key,
    this.brandLogoUrl,
    this.brandName,
    this.brandColor,
  });

  /// logo 尺寸 / 与名称间距（登录卡 440px 内紧凑布局）。
  static const double _logoSize = 40;
  static const double _logoGap = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 未指定品牌色时回退品牌主色（login-redesign §3 品牌紫强调）；
    // dark 下 primary 自动提亮（indigo-400），亮/暗主题均可读。
    final nameColor = brandColor ?? theme.colorScheme.primary;
    return Row(
      children: [
        if (brandLogoUrl != null) ...[
          // logo 发光容器（login-redesign-2 §3）：品牌紫光晕，凸显品牌块；
          // 纯装饰不影响语义（名称存在时 logo 语义排除逻辑不变）。
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.30),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Image.network(
              brandLogoUrl!,
              width: _logoSize,
              height: _logoSize,
              fit: BoxFit.contain,
              excludeFromSemantics: brandName != null,
              semanticLabel: brandName == null
                  ? context.tr('Organization logo')
                  : null,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: _logoGap),
        ],
        Expanded(
          child: Semantics(
            container: true,
            // 品牌名作为页面级标题，屏幕阅读器可跳转定位。
            header: true,
            child: Text(
              brandName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: nameColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
