import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import '../admin_module_groups.dart';
import '../admin_navigation.dart';

import 'commerce_models.dart';

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
          SectionHeader(
            'Immutable plan catalog',
            count: plans.length,
            action: FilledButton.icon(
              onPressed: onPublish,
              icon: const Icon(Icons.add, size: 18),
              label: const LocalizedText('Publish plan version'),
            ),
          ),
          const LocalizedText(
            'Published plan versions are immutable. Retire an old version and publish a new one to change commercial terms.',
          ),
          const Divider(),
          if (plans.isEmpty)
            EmptyState(
              compact: true,
              title: 'No plan versions are available.',
              actionLabel: 'Publish plan version',
              onAction: onPublish,
            )
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
    final statusLabel = plan['status']?.toString() ?? 'unknown';
    final subtitle =
        '${plan['billing_interval'] ?? 'none'} · $price · '
        '${features.values.where((value) => value == true).length} enabled features · '
        '${limits.length} quota grants';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        plan['status'] == 'active'
            ? Icons.sell_outlined
            : Icons.archive_outlined,
        color: adminModuleIconColor(AdminModuleId.commerce),
      ),
      title: Text(commercePlanLabel(plan)),
      subtitle: Text(subtitle),
      trailing: StatusChip(
        label: statusLabel,
        color: plan['status'] == 'active'
            ? AppColors.success
            : plan['status'] == 'retired'
            ? AppColors.muted
            : AppColors.warning,
        icon: plan['status'] == 'active'
            ? Icons.check_circle
            : Icons.circle_outlined,
      ),
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
          SectionHeader(
            'Tenant subscriptions',
            count: subscriptions.length,
            action: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_card_outlined, size: 18),
              label: const LocalizedText('Create subscription'),
            ),
          ),
          if (subscriptions.isEmpty)
            EmptyState(
              compact: true,
              title: 'This tenant has no subscriptions.',
              actionLabel: 'Create subscription',
              onAction: onCreate,
            )
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
    final title =
        '${subscription['status'] ?? 'unknown'} · ${plan['id'] ?? '—'} v${plan['version'] ?? '—'}';
    final period =
        'Period: ${formatServerTime(subscription['current_period_start'])} → ${formatServerTime(subscription['current_period_end'])}';
    final provider =
        'Provider reference: ${subscription['provider'] ?? '—'} / ${subscription['provider_subscription_id'] ?? '—'}';
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(label: LocalizedText('Revision {revision}', args: {'revision': revision})),
              ],
            ),
            SelectableText(subscription['id']?.toString() ?? '—'),
            const SizedBox(height: 4),
            Text(period),
            Text(provider),
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
          SectionHeader('Effective entitlement'),
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
    final stateLabel = entitlement!['active'] == true ? 'Active' : 'Inactive';
    final summary =
        '$stateLabel · '
        '${plan['id'] ?? '—'} v${plan['version'] ?? '—'} · '
        'revision ${entitlement!['revision'] ?? '—'}';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          entitlement!['active'] == true ? Icons.check_circle : Icons.block,
          color: entitlement!['active'] == true ? AppColors.success : AppColors.warning,
        ),
        Text(summary, style: Theme.of(context).textTheme.titleMedium),
        LocalizedText('Expires: {time}', args: {'time': formatServerTime(entitlement!['expires_at'])}),
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
              subtitle: Text(commerceGrant(entry.value)),
              trailing: _grantIcon(context, entry.value),
            ),
          ),
      ],
    );
  }

  Widget _grantIcon(BuildContext context, Object? value) {
    final grant = _map(value);
    if (grant['unlimited'] == true) return const Icon(Icons.all_inclusive);
    if (grant['hard'] == 0) {
      // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
      return Icon(
        Icons.block,
        color: AppColors.semanticFor(
          Theme.of(context).brightness,
          AppColors.danger,
        ),
      );
    }
    return const Icon(Icons.speed_outlined);
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
