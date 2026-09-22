import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';

/// Renders the composed client-instance/resource contract as local metadata.
///
/// This widget deliberately has no reader, callbacks, or device controls. A
/// caller must decode the shared contract before constructing it; the panel
/// therefore cannot turn a resource declaration into scheduling authority.
class ForgeClientInstanceResourceViewPanel extends StatelessWidget {
  final ForgeClientInstanceResourceView fixture;

  ForgeClientInstanceResourceViewPanel({super.key, required this.fixture})
    : assert(fixture.isDisplayOnly);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('forge-client-instance-resource-view-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Client instance resource view',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Read-only metadata; resources are unverified and cannot run work.',
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Owner declaration', [
              _valueRow(context, 'Issuer', fixture.owner.issuer),
              _valueRow(context, 'Subject', fixture.owner.subject),
              _valueRow(context, 'Tenant', fixture.owner.tenantID),
              _valueRow(context, 'Authority', 'offline'),
            ]),
            _section(context, 'Client instances', [
              for (final instance in fixture.instances)
                ListTile(
                  key: ValueKey(
                    'forge-client-instance-resource-view-${instance.instanceID}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(instance.instanceID),
                  subtitle: Text(
                    '${instance.clientKind} · ${instance.status} · '
                    'observed=${instance.observedAtMS} · '
                    'sessions=${instance.sessionIDs.join(', ')}',
                  ),
                ),
            ]),
            _section(context, 'Declared resources', [
              for (final device in fixture.devices)
                ListTile(
                  key: ValueKey(
                    'forge-client-instance-resource-view-${device.deviceID}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(device.deviceID),
                  subtitle: Text(
                    '${device.os}/${device.architecture} · '
                    'Runner ${device.runnerInstanceID} · '
                    '${device.liveness} · ${device.approvalState} · '
                    'reservation=${device.reservationState}\n'
                    'state: revision=${device.revision} · '
                    'generation=${device.generation} · '
                    'heartbeat=${device.heartbeatSequence} · '
                    'observed=${device.observedAtMS}\n'
                    'capacity: cpu=${device.availableCPUCores}/${device.cpuCores} · '
                    'memory=${device.availableMemoryBytes}/${device.memoryBytes} · '
                    'storage=${device.availableStorageBytes}/${device.storageBytes} · '
                    'gpu=${device.gpuCount} '
                    '(memory=${device.availableGPUMemoryBytes})',
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
