import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';

class TenantResidencySummary extends StatelessWidget {
  final Map<String, dynamic>? tenant;
  final String fallbackId;

  const TenantResidencySummary({
    super.key,
    required this.tenant,
    required this.fallbackId,
  });

  @override
  Widget build(BuildContext context) {
    final homeRegion = tenant?['home_region']?.toString().trim() ?? '';
    final allowedRegions = _stringList(tenant?['allowed_regions']);
    final enforceWrites = tenant?['enforce_writes'] == true;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.business, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenant?['name']?.toString() ?? fallbackId,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  LocalizedText(
                    'ID: {id}',
                    args: {'id': tenant?['id'] ?? fallbackId},
                  ),
                  LocalizedText(
                    'Domain: ${tenant?['domain'] ?? tenant?['primary_domain'] ?? ''}',
                  ),
                  ..._residencySection(
                    context,
                    homeRegion,
                    allowedRegions,
                    enforceWrites,
                  ),
                ],
              ),
            ),
            if (tenant?['status'] != null)
              Chip(
                label: LocalizedText(tenant!['status'].toString()),
                backgroundColor: tenant!['status'] == 'active'
                    ? AppColors.success.withValues(alpha: 0.10)
                    : AppColors.warning.withValues(alpha: 0.10),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _residencySection(
    BuildContext context,
    String homeRegion,
    List<String> allowedRegions,
    bool enforceWrites,
  ) {
    return [
      if (homeRegion.isNotEmpty ||
          allowedRegions.isNotEmpty ||
          enforceWrites) ...[
        const SizedBox(height: 12),
        _regionBadges(context, homeRegion, allowedRegions, enforceWrites),
      ],
    ];
  }

  Widget _regionBadges(
    BuildContext context,
    String homeRegion,
    List<String> allowedRegions,
    bool enforceWrites,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (homeRegion.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.home_outlined, size: 18),
            label: Text(
              context.tr('Home region: {region}', {'region': homeRegion}),
            ),
          ),
        if (allowedRegions.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.public, size: 18),
            label: Text(
              context.tr('Allowed serving regions: {regions}', {
                'regions': allowedRegions.join(', '),
              }),
            ),
          ),
        if (enforceWrites && homeRegion.isNotEmpty)
          const Chip(
            avatar: Icon(Icons.lock_outline, size: 18),
            label: LocalizedText('Write enforcement enabled'),
          ),
        if (enforceWrites && homeRegion.isEmpty)
          Chip(
            avatar: Icon(
              Icons.warning_amber,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            label: const LocalizedText(
              'Write enforcement is inactive because no home region is configured.',
            ),
          ),
      ],
    );
  }

  static List<String> _stringList(dynamic value) => value is List
      ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : const [];
}
