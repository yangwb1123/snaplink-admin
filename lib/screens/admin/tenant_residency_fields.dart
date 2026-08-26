import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

List<String> parseTenantRegions(String value) {
  final regions = <String>[];
  final seen = <String>{};
  for (final raw in value.split(RegExp(r'[,\n]'))) {
    final region = raw.trim();
    if (region.isNotEmpty && seen.add(region)) regions.add(region);
  }
  return regions;
}

class TenantResidencyFields extends StatelessWidget {
  final TextEditingController homeRegionController;
  final TextEditingController allowedRegionsController;
  final bool enforceWrites;
  final ValueChanged<bool> onEnforceWritesChanged;

  const TenantResidencyFields({
    super.key,
    required this.homeRegionController,
    required this.allowedRegionsController,
    required this.enforceWrites,
    required this.onEnforceWritesChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      LocalizedText(
        'Data residency',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      TextFormField(
        key: const ValueKey('tenant-home-region'),
        controller: homeRegionController,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Home region'.localized,
          helperText:
              'Primary region for tenant data. Leave blank for unconstrained residency.'
                  .localized,
          helperMaxLines: 3,
          errorMaxLines: 3,
        ),
        validator: (value) {
          if (enforceWrites && (value == null || value.trim().isEmpty)) {
            return 'Home region is required when write enforcement is enabled.'
                .localized;
          }
          return null;
        },
      ),
      const SizedBox(height: 8),
      TextFormField(
        key: const ValueKey('tenant-allowed-regions'),
        controller: allowedRegionsController,
        keyboardType: TextInputType.multiline,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          alignLabelWithHint: true,
          labelText: 'Allowed serving regions'.localized,
          helperText:
              'One per line or comma-separated; duplicates drop and the home region is always allowed.'
                  .localized,
          helperMaxLines: 4,
        ),
      ),
      SwitchListTile(
        key: const ValueKey('tenant-enforce-writes'),
        contentPadding: EdgeInsets.zero,
        title: const LocalizedText('Enforce writes in home region'),
        subtitle: const LocalizedText(
          'Reject token-issuing writes served outside the home region.',
        ),
        value: enforceWrites,
        onChanged: onEnforceWritesChanged,
      ),
    ],
  );
}
