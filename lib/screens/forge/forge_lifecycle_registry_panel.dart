import 'package:flutter/material.dart';

import 'package:sso_admin/api/forge_device_enrollment_heartbeat_lifecycle_registry.dart';

/// Renders the authenticated lifecycle-registry candidate as a display-only
/// owner-scoped snapshot. The panel has no reader or mutation callback, so it
/// cannot enroll a device, accept a heartbeat, publish inventory, reserve a
/// target, schedule, dispatch, or execute work.
class ForgeLifecycleRegistryPanel extends StatelessWidget {
  final ForgeDeviceEnrollmentHeartbeatLifecycleRegistry registry;

  ForgeLifecycleRegistryPanel({super.key, required this.registry})
    : assert(registry.isDisplayOnly);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('forge-lifecycle-registry-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Lifecycle registry candidate',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Read-only authenticated restart snapshot; no enrollment or execution authority.',
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Envelope', [
              _valueRow(context, 'Schema', registry.schemaVersion),
              _valueRow(context, 'Issuer', registry.owner.issuer),
              _valueRow(context, 'Subject', registry.owner.subject),
              _valueRow(context, 'Tenant', registry.owner.tenantID),
              _valueRow(context, 'States', '${registry.states.length}'),
            ]),
            _section(context, 'Bound lifecycle states', [
              for (final state in registry.states)
                ListTile(
                  key: ValueKey(
                    'forge-lifecycle-registry-${state.deviceID}-${state.instanceID}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(state.deviceID),
                  subtitle: Text(
                    'Runner ${state.instanceID} · revision=${state.revision} · '
                    'generation=${state.generation} · heartbeat=${state.heartbeatSequence}\n'
                    '${state.approvalState}/${state.credentialState} · '
                    'cordon=${state.cordonState} · reservation=${state.reservationState} · '
                    'liveness=${state.liveness}',
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      );

  Widget _valueRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
