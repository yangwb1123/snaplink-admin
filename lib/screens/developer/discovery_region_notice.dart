import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

class DiscoveryRegionNotice extends StatelessWidget {
  final String servingRegion;

  const DiscoveryRegionNotice({super.key, required this.servingRegion});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: context.tr('Serving region: {region}', {'region': servingRegion}),
      child: Material(
        color: colors.secondaryContainer,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.public),
          title: Text(
            context.tr('Serving region: {region}', {'region': servingRegion}),
          ),
          subtitle: Text(
            context.tr(
              'Advertised by OpenID Discovery as deployment provenance, not the user location.',
            ),
          ),
        ),
      ),
    );
  }
}
