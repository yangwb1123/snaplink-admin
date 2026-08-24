import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// 租户品牌头：logo（网络图片）+ 名称，品牌色可覆盖。
///
/// 品牌图片始终占据固定 slot；加载失败只替换 slot 内的本地占位，不让
/// 品牌名称横移。名称存在时 logo 是装饰，名称缺失时 logo 继续承担
/// `Organization logo` 语义。
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

  /// logo 内容尺寸 / 品牌 slot / 与名称间距。
  static const double _logoSize = 40;
  static const double _logoSlot = 48;
  static const double _logoGap = 12;

  /// 低对比或带透明度的租户色回退到主题品牌色。
  static Color resolveBrandColor(ThemeData theme, Color? requested) {
    final fallback = theme.colorScheme.primary;
    if (requested == null) return fallback;
    final visible = Color.alphaBlend(requested, theme.colorScheme.surface);
    final first = visible.computeLuminance();
    final second = theme.colorScheme.surface.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    final contrast = (lighter + 0.05) / (darker + 0.05);
    return contrast >= 3 ? requested : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasName = brandName?.trim().isNotEmpty ?? false;
    final nameColor = resolveBrandColor(theme, brandColor);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (brandLogoUrl != null) ...[
          Container(
            width: _logoSlot,
            height: _logoSlot,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.16 : 0.12,
                  ),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Image.network(
                brandLogoUrl!,
                width: _logoSize,
                height: _logoSize,
                fit: BoxFit.contain,
                excludeFromSemantics: hasName,
                semanticLabel: hasName ? null : context.tr('Organization logo'),
                errorBuilder: (_, _, _) => _logoFallback(context),
              ),
            ),
          ),
          if (hasName) const SizedBox(width: _logoGap),
        ],
        if (hasName)
          Expanded(
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                brandName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: nameColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _logoFallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      child: Icon(
        Icons.business_outlined,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
