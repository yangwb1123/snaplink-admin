import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Deployment-provenance banner shown above the developer tabs when OpenID
/// Discovery advertises a serving region. The region is server-declared
/// provenance — where the deployment is served from — not the user's
/// location; the copy keeps that distinction explicit.
class DiscoveryRegionNotice extends StatelessWidget {
  final String servingRegion;

  const DiscoveryRegionNotice({super.key, required this.servingRegion});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: context.tr('Serving region: {region}', {'region': servingRegion}),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.onSecondaryContainer.withValues(alpha: 0.25),
          ),
        ),
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.public, size: 18, color: scheme.primary),
          ),
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
