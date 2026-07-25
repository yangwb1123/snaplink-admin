import 'package:flutter/material.dart';

/// Tenant data export card.
class OrganizationExportCard extends StatelessWidget {
  final String tenantId;
  final bool mutating;
  final VoidCallback onExport;

  const OrganizationExportCard({
    super.key,
    required this.tenantId,
    required this.mutating,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tenant data export', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Downloads a machine-readable snapshot of a tenant\'s membership, '
            'clients, permissions, sessions, consents, connections and audit events. '
            'PII is included — handle the file securely.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: tenantId.isEmpty || mutating ? null : onExport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export tenant data'),
          ),
        ],
      ),
    ),
  );
}
