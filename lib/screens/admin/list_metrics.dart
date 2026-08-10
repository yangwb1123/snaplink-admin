import 'package:flutter/material.dart';
import 'package:sso_admin/api/audit_event_row.dart';
import 'package:sso_admin/services/list_page_metrics.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';

/// Wave-1 list-page metric strips + distribution bars (§4.2–§4.5).
///
/// All aggregates come from the CURRENT PAGE payload (caption "On this
/// page"); the server `totalSize` is labeled "Total" without a caption.
/// No delta/sparkline anywhere (honesty rule — no series exist in wave 1).

/// Fixed provider palette for the users distribution bar (AppColors only).
const _providerPalette = <Color>[
  AppColors.primary,
  AppColors.accentBlue,
  AppColors.success,
  AppColors.warning,
  AppColors.violet,
  AppColors.cyan,
  AppColors.pink,
];

/// Clients: Total · Active · Inactive · Secrets expiring + status bar.
class ClientMetrics extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int? totalSize;
  final OperatorPersona persona;

  const ClientMetrics({
    super.key,
    required this.items,
    this.totalSize,
    this.persona = OperatorPersona.general,
  });

  @override
  Widget build(BuildContext context) {
    final page = clientPageMetrics(items);
    final cards = <KeyMetricCard>[
      KeyMetricCard(
        label: 'Total',
        value: totalSize ?? page.active + page.inactive,
        icon: Icons.inventory_2_outlined,
        color: AppColors.primary,
      ),
      KeyMetricCard(
        label: 'Active',
        value: page.active,
        caption: 'On this page',
        // filled 变体：与批量操作条的 outline 图标区分（避免 finder 冲突）。
        icon: Icons.check_circle,
        color: AppColors.success,
      ),
      KeyMetricCard(
        label: 'Inactive',
        value: page.inactive,
        caption: 'On this page',
        icon: Icons.circle_outlined,
        color: AppColors.muted,
      ),
      KeyMetricCard(
        label: 'Secrets expiring',
        value: page.secretsExpiring,
        caption: 'On this page',
        icon: Icons.key_outlined,
        color: AppColors.warning,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricStrip(
          cards: [
            for (final metric in clientMetricOrder(persona))
              cards[metric.index],
          ],
        ),
        const SizedBox(height: 12),
        DistributionBar(
          segments: [
            DistributionSegment(
              label: 'Active',
              value: page.active,
              color: AppColors.success,
            ),
            DistributionSegment(
              label: 'Inactive',
              value: page.inactive,
              color: AppColors.muted,
            ),
          ],
          emphasizedLabel: clientsBarEmphasis(persona),
        ),
      ],
    );
  }
}

/// Users: Total · Providers (page) + per-provider distribution bar.
class UserMetrics extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int? totalSize;
  final OperatorPersona persona;

  const UserMetrics({
    super.key,
    required this.items,
    this.totalSize,
    this.persona = OperatorPersona.general,
  });

  @override
  Widget build(BuildContext context) {
    final providers = userProviderCounts(items);
    final cards = <KeyMetricCard>[
      KeyMetricCard(
        label: 'Total',
        value: totalSize ?? items.length,
        icon: Icons.people_outline,
        color: AppColors.primary,
      ),
      KeyMetricCard(
        label: 'Providers',
        value: providers.length,
        caption: 'On this page',
        icon: Icons.dns_outlined,
        color: AppColors.accentBlue,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricStrip(
          cards: [
            for (final metric in userMetricOrder(persona)) cards[metric.index],
          ],
        ),
        const SizedBox(height: 12),
        DistributionBar(
          segments: [
            for (var i = 0; i < providers.entries.length; i++)
              DistributionSegment(
                label: providers.entries.elementAt(i).key,
                value: providers.entries.elementAt(i).value,
                color: _providerPalette[i % _providerPalette.length],
              ),
          ],
        ),
      ],
    );
  }
}

/// Tenants: Total · Active · Suspended (page) + status bar.
class TenantMetrics extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int? totalSize;
  final OperatorPersona persona;

  const TenantMetrics({
    super.key,
    required this.items,
    this.totalSize,
    this.persona = OperatorPersona.general,
  });

  @override
  Widget build(BuildContext context) {
    final page = tenantPageMetrics(items);
    final cards = <KeyMetricCard>[
      KeyMetricCard(
        label: 'Total',
        value: totalSize ?? page.active + page.suspended,
        icon: Icons.business_outlined,
        color: AppColors.primary,
      ),
      KeyMetricCard(
        label: 'Active',
        value: page.active,
        caption: 'On this page',
        icon: Icons.check_circle,
        color: AppColors.success,
      ),
      KeyMetricCard(
        label: 'Suspended',
        value: page.suspended,
        caption: 'On this page',
        // filled 变体：与批量操作条的 outline 图标区分（避免 finder 冲突）。
        icon: Icons.pause_circle,
        color: AppColors.warning,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricStrip(
          cards: [
            for (final metric in tenantMetricOrder(persona))
              cards[metric.index],
          ],
        ),
        const SizedBox(height: 12),
        DistributionBar(
          segments: [
            DistributionSegment(
              label: 'Active',
              value: page.active,
              color: AppColors.success,
            ),
            DistributionSegment(
              label: 'Suspended',
              value: page.suspended,
              color: AppColors.warning,
            ),
          ],
          emphasizedLabel: tenantsBarEmphasis(persona),
        ),
      ],
    );
  }
}

/// Audit: Entries · Error rate % · Event types (page) + success/failure bar.
class AuditMetrics extends StatelessWidget {
  final List<AuditEventRow> rows;
  final OperatorPersona persona;

  const AuditMetrics({
    super.key,
    required this.rows,
    this.persona = OperatorPersona.general,
  });

  @override
  Widget build(BuildContext context) {
    final page = auditPageMetrics(rows);
    final errorRate = rows.isEmpty ? 0 : page.errors * 100.0 / rows.length;
    final cards = <KeyMetricCard>[
      KeyMetricCard(
        label: 'Entries',
        value: rows.length,
        caption: 'On this page',
        icon: Icons.receipt_long_outlined,
        color: AppColors.primary,
      ),
      KeyMetricCard(
        label: 'Error rate',
        value: errorRate,
        fractionDigits: 0,
        caption: 'On this page',
        icon: Icons.error_outline,
        color: errorRate >= 20
            ? AppColors.danger
            : errorRate >= 5
            ? AppColors.warning
            : AppColors.success,
      ),
      KeyMetricCard(
        label: 'Event types',
        value: page.eventTypes,
        caption: 'On this page',
        icon: Icons.category_outlined,
        color: AppColors.accentBlue,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricStrip(
          cards: [
            for (final metric in auditMetricOrder(persona)) cards[metric.index],
          ],
        ),
        // Bars only when the page has rows (no 0% claim on an empty page).
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          DistributionBar(
            segments: [
              DistributionSegment(
                label: 'Success',
                value: page.entries - page.errors,
                color: AppColors.success,
              ),
              DistributionSegment(
                label: 'Failure',
                value: page.errors,
                color: AppColors.danger,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
