import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import '../admin_module_groups.dart';
import '../admin_navigation.dart';

/// Tenant commerce entry point: chooses the tenant + currency pair to load
/// and shows the error card when the commerce service is unavailable.
class CommerceTenantSelector extends StatelessWidget {
  final TextEditingController tenant;
  final TextEditingController currency;
  final bool enabled;
  final VoidCallback onLoad;

  const CommerceTenantSelector({
    super.key,
    required this.tenant,
    required this.currency,
    required this.enabled,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tenantField = TextField(
            controller: tenant,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: 'Tenant ID'.localized),
          );
          final currencyField = TextField(
            controller: currency,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: enabled ? (_) => onLoad() : null,
            decoration: InputDecoration(labelText: 'Currency'.localized),
          );
          final loadButton = FilledButton.icon(
            onPressed: enabled ? onLoad : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: Icon(
              Icons.search,
              color: adminModuleIconColor(AdminModuleId.commerce),
            ),
            label: const LocalizedText('Load tenant commerce'),
          );

          // Fixed-width children in the old Wrap could exceed a phone's
          // inner width (and leave the load action partly off-screen).
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tenantField,
                const SizedBox(height: 12),
                currencyField,
                const SizedBox(height: 12),
                loadButton,
              ],
            );
          }
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 320, child: tenantField),
              SizedBox(width: 140, child: currencyField),
              loadButton,
            ],
          );
        },
      ),
    ),
  );
}

class CommerceErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const CommerceErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: const LocalizedText('Commerce service error'),
      subtitle: Text(message),
      trailing: onRetry == null
          ? null
          : IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry'.localized,
            ),
    ),
  );
}
