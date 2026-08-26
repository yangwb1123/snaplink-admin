import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/status_chip.dart';

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
    final name = tenant?['name']?.toString() ?? fallbackId;
    final id = tenant?['id'] ?? fallbackId;
    final domain =
        'Domain: ${tenant?['domain'] ?? tenant?['primary_domain'] ?? ''}';
    final status = tenant?['status'] == null
        ? null
        : tenant!['status'] == 'active'
        ? StatusChip.active(label: context.tr('active'))
        : StatusChip.suspended(label: context.tr('suspended'));

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = _tenantDetails(context, name, id, domain);
            final residency = _residencySection(
              context,
              homeRegion,
              allowedRegions,
              enforceWrites,
            );
            // Keep status out of the identity row on phones. The identity
            // card remains a metric/card surface while long tenant and region
            // values receive the full available width below the header.
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.business, size: 48),
                      const SizedBox(width: 16),
                      Expanded(child: details),
                    ],
                  ),
                  ...residency,
                  if (status case final chip?) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: chip,
                    ),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.business, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [details, ...residency],
                  ),
                ),
                ?status,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tenantDetails(
    BuildContext context,
    String name,
    dynamic id,
    String domain,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(name, style: Theme.of(context).textTheme.titleMedium),
      LocalizedText('ID: {id}', args: {'id': id}),
      Text(domain),
    ],
  );

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 600.0;
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (homeRegion.isNotEmpty)
              _boundedChip(
                maxWidth: maxWidth,
                avatar: Icon(
                  Icons.home_outlined,
                  size: 18,
                  color: AppColors.groupTenants,
                ),
                label: Text(
                  context.tr('Home region: {region}', {'region': homeRegion}),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (allowedRegions.isNotEmpty)
              _boundedChip(
                maxWidth: maxWidth,
                avatar: Icon(
                  Icons.public,
                  size: 18,
                  color: AppColors.groupTenants,
                ),
                label: Text(
                  context.tr('Allowed serving regions: {regions}', {
                    'regions': allowedRegions.join(', '),
                  }),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (enforceWrites && homeRegion.isNotEmpty)
              _boundedChip(
                maxWidth: maxWidth,
                avatar: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.groupTenants,
                ),
                label: const LocalizedText(
                  'Write enforcement enabled',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (enforceWrites && homeRegion.isEmpty)
              _boundedChip(
                maxWidth: maxWidth,
                avatar: Icon(
                  Icons.warning_amber,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: const LocalizedText(
                  'Write enforcement is inactive because no home region is configured.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _boundedChip({
    required double maxWidth,
    required Widget avatar,
    required Widget label,
  }) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Chip(avatar: avatar, label: label),
  );

  static List<String> _stringList(dynamic value) => value is List
      ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : const [];
}
