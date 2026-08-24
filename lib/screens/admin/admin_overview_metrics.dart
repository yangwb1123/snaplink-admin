import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'snaplink_admin_api.dart';

/// Overview metrics are scalar counts/statuses, so cards remain the primary
/// expression. No trend is shown: this endpoint has no historical series.
class OverviewMetrics extends StatelessWidget {
  final List<SnaplinkAdminEndpoint> endpoints;
  final int featureGroups;
  final int documentedOnly;
  final bool commerceAvailable;
  final Object? commerceProbeError;
  final OperatorPersona persona;
  final bool showValues;

  const OverviewMetrics({
    super.key,
    required this.endpoints,
    required this.featureGroups,
    required this.documentedOnly,
    required this.commerceAvailable,
    this.commerceProbeError,
    this.persona = OperatorPersona.general,
    this.showValues = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showValues) return StatusChip.unknown(label: context.tr('Unknown'));
    final commerceCaption = commerceProbeError != null
        ? 'Degraded'
        : commerceAvailable
        ? 'Available'
        : 'Not advertised';
    final cards = <KeyMetricCard>[
      KeyMetricCard(
        label: 'Live endpoints',
        value: endpoints.length,
        icon: Icons.hub_outlined,
        color: AppColors.primary,
      ),
      KeyMetricCard(
        label: 'Feature groups',
        value: featureGroups,
        icon: Icons.widgets_outlined,
        color: AppColors.accentBlue,
      ),
      KeyMetricCard(
        label: 'Documented-only routes',
        value: documentedOnly,
        icon: Icons.description_outlined,
        color: AppColors.warning,
      ),
      KeyMetricCard(
        label: 'Commerce availability',
        value: commerceAvailable ? 1 : 0,
        icon: Icons.storefront_outlined,
        color: AppColors.success,
        caption: commerceCaption,
      ),
    ];
    final ordered = <KeyMetricCard>[
      for (final metric in overviewMetricOrder(persona)) cards[metric.index],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // A full-width card is easier to scan at 320/400 than a 190px card
        // floating in a narrow column. Medium and desktop retain the dense
        // four-card wrap supplied by MetricStrip.
        final cardWidth = constraints.maxWidth < 420
            ? constraints.maxWidth
            : 190.0;
        return MetricStrip(cards: ordered, cardWidth: cardWidth);
      },
    );
  }
}

/// Persona ordering changes emphasis only; it never gates a group or route.
List<String> personaGroupOrder(
  List<String> groupKeys,
  OperatorPersona persona, {
  required Map<String, List<String>> pathsByGroup,
}) {
  if (groupKeys.length < 2) return groupKeys;
  String? lead;
  switch (persona) {
    case OperatorPersona.securityOps:
      lead = 'Security operations';
    case OperatorPersona.identityOps:
      lead = 'Identity and connections';
    case OperatorPersona.auditor:
      lead = 'Governance and compliance';
    case OperatorPersona.support:
      for (final key in groupKeys) {
        final paths = pathsByGroup[key] ?? const <String>[];
        if (paths.any(
          (path) =>
              path.contains('user-support') || path.contains('live-activity'),
        )) {
          lead = key;
          break;
        }
      }
    case OperatorPersona.full:
    case OperatorPersona.general:
      break;
  }
  if (lead == null || !groupKeys.contains(lead)) return groupKeys;
  return [lead, ...groupKeys.where((key) => key != lead)];
}
