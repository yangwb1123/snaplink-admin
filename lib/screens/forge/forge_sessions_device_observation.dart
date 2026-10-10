import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/api/forge_session_device_observation_wire.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'forge_device_inventory_panel.dart';

part 'forge_session_device_observation_model.dart';

class ForgeSessionDeviceObservationError implements Exception {
  final String code;

  const ForgeSessionDeviceObservationError(this.code);

  @override
  String toString() => 'ForgeSessionDeviceObservationError($code)';
}

/// Renders the binding and the existing read-only inventory panel together.
/// The binding card makes it clear which Conversation/Run the declaration is
/// for; all device values remain unverified and no action is offered.
class ForgeSessionDeviceObservationPanel extends StatelessWidget {
  final ForgeSessionDeviceObservation observation;

  const ForgeSessionDeviceObservationPanel({
    super.key,
    required this.observation,
  });

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('forge-session-device-observation'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Offline device observation'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                context.tr('Conversation: {id}', {
                  'id': observation.conversationID,
                }),
              ),
              Text(context.tr('Run: {id}', {'id': observation.runID})),
              Text(
                context.tr(
                  'This placement is a caller-supplied preview. It selects no target and grants no execution authority.',
                ),
              ),
            ],
          ),
        ),
      ),
      ForgeDeviceInventoryPanel(
        page: observation.page,
        snapshot: observation.snapshot,
        placement: observation.placement,
        resourceSummary: observation.resourceSummary,
        statusByDeviceInstance: observation.statusByDeviceInstance,
      ),
    ],
  );
}
