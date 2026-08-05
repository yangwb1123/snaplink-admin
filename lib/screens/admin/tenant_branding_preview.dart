import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (logoUrl.isNotEmpty)
            Image.network(
              logoUrl,
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
