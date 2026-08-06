import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/sensitive_data.dart';

class ConnectionDetailsCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic>? connection;
  final Map<String, dynamic>? health;
  final List<Map<String, dynamic>> domainClaims;
  final bool loading;
  final bool mutating;
  final bool canProbe;
  final bool canListDomains;
  final bool canVerifyDomain;
  final bool canDelete;
  final VoidCallback onRefresh;
  final VoidCallback onProbe;
  final VoidCallback onDelete;
  final ValueChanged<String> onVerifyDomain;

  const ConnectionDetailsCard({
    super.key,
    required this.id,
    required this.connection,
    required this.health,
    required this.domainClaims,
    required this.loading,
    required this.mutating,
    required this.canProbe,
    required this.canListDomains,
    required this.canVerifyDomain,
    required this.canDelete,
    required this.onRefresh,
    required this.onProbe,
    required this.onDelete,
    required this.onVerifyDomain,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: LocalizedText(
                  'Connection: $id',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: loading || mutating ? null : onRefresh,
                tooltip: 'Refresh connection'.localized,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (connection != null) _summary(context),
            if (health != null) _healthCard(context),
            if (canProbe) _probeCard(),
            if (canListDomains) _domainsCard(context),
            if (canDelete)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: mutating ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const LocalizedText('Delete connection'),
                ),
              ),
          ],
        ],
      ),
    ),
  );

  Widget _summary(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          '${connection!['display_name'] ?? connection!['id']} · ${connection!['type'] ?? ''}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        LocalizedText(
          connection!['enabled'] == false ? 'Disabled' : 'Enabled',
          style: TextStyle(
            color: connection!['enabled'] == false
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        if (connection!['config'] is Map)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              const JsonEncoder.withIndent(
                '  ',
              ).convert(SensitiveData.redact(connection!['config'])),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    ),
  );

  Widget _healthCard(BuildContext context) {
    final status = health!['status']?.toString() ?? 'unknown';
    final color = switch (status) {
      'healthy' => Colors.green,
      'degraded' => Colors.orange,
      'unreachable' => Colors.red,
      _ => Colors.blueGrey,
    };
    final checked = health!['last_checked_at']?.toString();
    final success = health!['last_success_at']?.toString();
    final error = health!['last_error']?.toString();
    final detail = [
      'Connection $id',
      if (checked != null && checked.isNotEmpty) 'checked $checked',
      if (success != null && success.isNotEmpty) 'last healthy $success',
      if (error != null && error.isNotEmpty) error,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: ListTile(
        leading: Icon(Icons.monitor_heart_outlined, color: color),
        title: Row(
          children: [
            Flexible(child: LocalizedText('Upstream health')),
            const SizedBox(width: 8),
            switch (status) {
              'healthy' => StatusChip.healthy(),
              'degraded' => StatusChip(
                  label: 'Degraded', color: AppColors.warning,
                  icon: Icons.warning_amber),
              'unreachable' => StatusChip.unhealthy(),
              _ => StatusChip.inactive(),
            },
          ],
        ),
        subtitle: Text(detail),
      ),
    );
  }

  Widget _probeCard() => Card(
    margin: const EdgeInsets.only(top: 16),
    child: ListTile(
      leading: const Icon(Icons.network_ping_outlined),
      title: const LocalizedText('Reachability probe'),
      subtitle: const LocalizedText(
        'Fetches the OIDC discovery document or SAML metadata and records the result.',
      ),
      trailing: FilledButton(
        onPressed: mutating ? null : onProbe,
        child: const LocalizedText('Probe'),
      ),
    ),
  );

  Widget _domainsCard(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'Domain ownership',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const LocalizedText(
            'Publish each DNS TXT record and then verify it. The challenge value is public DNS data, not a bearer secret.',
          ),
          if (domainClaims.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalizedText('No domain claims found.'),
            ),
          for (final claim in domainClaims)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                claim['status'] == 'verified'
                    ? Icons.verified_outlined
                    : Icons.pending_outlined,
                color: claim['status'] == 'verified'
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(claim['domain']?.toString() ?? ''),
              subtitle: SelectableText(
                '${claim['status'] ?? 'pending'}\nTXT ${claim['record'] ?? ''}\n${claim['token'] ?? ''}',
              ),
              trailing: canVerifyDomain && claim['status'] != 'verified'
                  ? TextButton(
                      onPressed: mutating
                          ? null
                          : () => onVerifyDomain(
                              claim['domain']?.toString() ?? '',
                            ),
                      child: const LocalizedText('Verify'),
                    )
                  : null,
            ),
        ],
      ),
    ),
  );
}
