import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'commerce_models.dart';

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
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: tenant,
              decoration: InputDecoration(labelText: 'Tenant ID'.localized),
            ),
          ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: currency,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: 'Currency'.localized),
            ),
          ),
          FilledButton.icon(
            onPressed: enabled ? onLoad : null,
            icon: const Icon(Icons.search),
            label: const LocalizedText('Load tenant commerce'),
          ),
        ],
      ),
    ),
  );
}

class CommerceErrorCard extends StatelessWidget {
  final String message;

  const CommerceErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: const LocalizedText('Commerce service error'),
      subtitle: Text(message),
    ),
  );
}

class CommercePlansPanel extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final VoidCallback? onPublish;

  const CommercePlansPanel({
    super.key,
    required this.plans,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(
            context,
            'Immutable plan catalog',
            FilledButton.icon(
              onPressed: onPublish,
              icon: const Icon(Icons.add),
              label: const LocalizedText('Publish plan version'),
            ),
          ),
          const LocalizedText(
            'Published plan versions are immutable. Retire an old version and publish a new one to change commercial terms.',
          ),
          const Divider(),
          if (plans.isEmpty)
            const LocalizedText('No plan versions are available.')
          else
            ...plans.map((plan) => _planTile(context, plan)),
        ],
      ),
    ),
  );

  Widget _planTile(BuildContext context, Map<String, dynamic> plan) {
    final features = _map(plan['features']);
    final limits = _map(plan['limits']);
    final price = commerceMinorUnits(_map(plan['price']));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        plan['status'] == 'active'
            ? Icons.sell_outlined
            : Icons.archive_outlined,
      ),
      title: Text(commercePlanLabel(plan)),
      subtitle: LocalizedText(
        '${plan['billing_interval'] ?? 'none'} · $price · '
        '${features.values.where((value) => value == true).length} enabled features · '
        '${limits.length} quota grants',
      ),
      trailing: Chip(label: Text(plan['status']?.toString() ?? '—')),
    );
  }
}

class CommerceSubscriptionsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> subscriptions;
  final VoidCallback? onCreate;
  final ValueChanged<Map<String, dynamic>>? onStatus;
  final ValueChanged<Map<String, dynamic>>? onChangePlan;
  final ValueChanged<Map<String, dynamic>>? onRenew;

  const CommerceSubscriptionsPanel({
    super.key,
    required this.subscriptions,
    required this.onCreate,
    required this.onStatus,
    required this.onChangePlan,
    required this.onRenew,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(
            context,
            'Tenant subscriptions',
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_card_outlined),
              label: const LocalizedText('Create subscription'),
            ),
          ),
          if (subscriptions.isEmpty)
            const LocalizedText('This tenant has no subscriptions.')
          else
            ...subscriptions.map(
              (subscription) => _subscriptionCard(context, subscription),
            ),
        ],
      ),
    ),
  );

  Widget _subscriptionCard(
    BuildContext context,
    Map<String, dynamic> subscription,
  ) {
    final plan = commercePlanRef(subscription);
    final revision = subscription['revision']?.toString() ?? '—';
    final isLive = commerceSubscriptionIsLive(subscription);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LocalizedText(
                    '${subscription['status'] ?? 'unknown'} · ${plan['id'] ?? '—'} v${plan['version'] ?? '—'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: LocalizedText('Revision $revision')),
              ],
            ),
            SelectableText(subscription['id']?.toString() ?? '—'),
            const SizedBox(height: 4),
            LocalizedText(
              'Period: ${subscription['current_period_start'] ?? '—'} → ${subscription['current_period_end'] ?? '—'}',
            ),
            LocalizedText(
              'Provider reference: ${subscription['provider'] ?? '—'} / ${subscription['provider_subscription_id'] ?? '—'}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onStatus == null
                      ? null
                      : () => onStatus!(subscription),
                  child: const LocalizedText('Change status'),
                ),
                OutlinedButton(
                  onPressed: onChangePlan == null || !isLive
                      ? null
                      : () => onChangePlan!(subscription),
                  child: const LocalizedText('Change plan'),
                ),
                OutlinedButton(
                  onPressed: onRenew == null || !isLive
                      ? null
                      : () => onRenew!(subscription),
                  child: const LocalizedText('Administrative renewal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CommerceEntitlementPanel extends StatelessWidget {
  final Map<String, dynamic>? entitlement;

  const CommerceEntitlementPanel({super.key, required this.entitlement});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(context, 'Effective entitlement', null),
          if (entitlement == null)
            const LocalizedText(
              'No entitlement projection exists for this tenant.',
            )
          else ...[
            _summary(context),
            const Divider(),
            _features(context),
            const SizedBox(height: 12),
            _limits(context),
          ],
        ],
      ),
    ),
  );

  Widget _summary(BuildContext context) {
    final plan = _map(entitlement!['plan']);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          entitlement!['active'] == true ? Icons.check_circle : Icons.block,
          color: entitlement!['active'] == true ? Colors.green : Colors.orange,
        ),
        LocalizedText(
          '${entitlement!['active'] == true ? 'Active' : 'Inactive'} · '
          '${plan['id'] ?? '—'} v${plan['version'] ?? '—'} · '
          'revision ${entitlement!['revision'] ?? '—'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        LocalizedText('Expires: ${entitlement!['expires_at'] ?? '—'}'),
      ],
    );
  }

  Widget _features(BuildContext context) {
    final features = _map(entitlement!['features']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          'Features',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (features.isEmpty)
          const LocalizedText('No features are granted.')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: features.entries
                .map(
                  (entry) => Chip(
                    avatar: Icon(
                      entry.value == true ? Icons.check : Icons.close,
                      size: 16,
                    ),
                    label: Text(entry.key),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _limits(BuildContext context) {
    final limits = _map(entitlement!['limits']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          'Quota grants',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (limits.isEmpty)
          const LocalizedText('No quota grants are projected.')
        else
          ...limits.entries.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              subtitle: LocalizedText(commerceGrant(entry.value)),
              trailing: _grantIcon(entry.value),
            ),
          ),
      ],
    );
  }

  Widget _grantIcon(Object? value) {
    final grant = _map(value);
    if (grant['unlimited'] == true) return const Icon(Icons.all_inclusive);
    if (grant['hard'] == 0) {
      return const Icon(Icons.block, color: Colors.redAccent);
    }
    return const Icon(Icons.speed_outlined);
  }
}

Widget _panelHeader(BuildContext context, String title, Widget? action) => Row(
  children: [
    Expanded(
      child: LocalizedText(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ),
    ?action,
  ],
);

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
