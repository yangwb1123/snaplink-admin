import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/screens/oidc_login/hosted_login_models.dart';
import 'package:sso_admin/services/product_api_origin.dart';

/// 品牌预览：所见即所得。logo 与登录页走同一 `resolveSafeHostedUrl` 解析
/// （相对/跨源/非 https 一律不渲染），网络加载失败时降级为占位图标
/// （编辑器语境需要可见的失败信号，与登录页静默隐藏不同）。
class TenantBrandingPreview extends StatelessWidget {
  final String brandName;
  final String primaryColor;
  final String logoUrl;

  const TenantBrandingPreview({
    super.key,
    required this.brandName,
    required this.primaryColor,
    required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final match = RegExp(
      r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$',
    ).firstMatch(primaryColor);
    final color = match == null
        ? Theme.of(context).colorScheme.primary
        : Color(
            int.parse('${match.group(2) ?? 'ff'}${match.group(1)}', radix: 16),
          );
    // 与登录页 `_applyBranding` 同一解析规则：预览只展示登录页实际会
    // 渲染的 logo，避免编辑器看到一张登录端永远不会出现的图片。
    final safeLogoUrl = resolveSafeHostedUrl(
      logoUrl,
      ProductApiOrigin.baseUri,
    )?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (safeLogoUrl != null)
            Image.network(
              safeLogoUrl,
              height: 44,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          if (brandName.isEmpty)
            LocalizedText(
              'Your organization',
              style: Theme.of(context).textTheme.titleMedium,
            )
          else
            Text(brandName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: null,
            child: const LocalizedText('Continue'),
          ),
        ],
      ),
    );
  }
}
