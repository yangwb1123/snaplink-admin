import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Branding header with logo and name.
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

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (brandLogoUrl != null) ...[
        Image.network(
          brandLogoUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          excludeFromSemantics: brandName != null,
          semanticLabel: brandName == null
              ? context.tr('Organization logo')
              : null,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Text(
          brandName ?? '',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: brandColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}
