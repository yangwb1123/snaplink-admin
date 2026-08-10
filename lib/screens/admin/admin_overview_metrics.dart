import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';

import 'package:sso_admin/services/operator_persona.dart';
import 'snaplink_admin_api.dart';

/// Overview hero metric strip (§4.1 of the design).
///
/// Four real-value [KeyMetricCard]s in `overviewMetricOrder(persona)`
/// (design §4.9 T-01). No delta/sparkline anywhere in wave 1 — no series
/// exist (honesty rule).
class OverviewMetrics extends StatelessWidget {
  final List<SnaplinkAdminEndpoint> endpoints;
  final int featureGroups;
  final int documentedOnly;
  final bool commerceAvailable;
  final Object? commerceProbeError;
  final OperatorPersona persona;

  const OverviewMetrics({
    super.key,
    required this.endpoints,
    required this.featureGroups,
    required this.documentedOnly,
    required this.commerceAvailable,
    this.commerceProbeError,
    this.persona = OperatorPersona.general,
  });

  @override
  Widget build(BuildContext context) {
    // Commerce caption from the probe pair: (true, null) → 'Available',
    // (false, null) → 'Not advertised' (403/404-unavailable),
    // (_, non-null) → 'Degraded'. No arrow either way.
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
    return MetricStrip(cards: ordered);
  }
}

/// Persona-driven ordering of the management-domain group cards (§4.1).
///
/// Pure: returns the lead-first permutation of the *present* group keys;
/// a persona whose lead group is absent (or `full`/`general`) keeps the
/// insertion order (today's rendering). `pathsByGroup` is used only by the
/// `support` row (groups containing user-support/live-activity endpoints
/// lead, presence-checked).
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
