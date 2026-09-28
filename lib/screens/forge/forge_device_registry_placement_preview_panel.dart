import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'package:sso_admin/api/forge_device_registry_placement_preview.dart';

/// Displays the authenticated registry placement candidate. It has no
/// selection, reservation, scheduling, or execution callback.
class ForgeDeviceRegistryPlacementPreviewPanel extends StatelessWidget {
  final ForgeDeviceRegistryPlacementPreview preview;

  const ForgeDeviceRegistryPlacementPreviewPanel({
    super.key,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final decisions = List<ForgeDeviceRegistryPlacementDecision>.of(
      preview.decisions,
    );
    return Card(
      key: const ValueKey('forge-device-registry-placement-preview-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalizedText(
              'Registry placement preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const LocalizedText(
              'Authenticated read-only comparison over the persisted registry; no target was selected and all authority is false.',
            ),
            _row('Evaluated at', '${preview.evaluatedAtMS}'),
            _row('Eligible candidates', '${preview.eligibleCandidateCount}'),
            _row('Selected device', preview.selectedDeviceID ?? 'none'),
            _row('Selected instance', preview.selectedInstanceID ?? 'none'),
            _row('Authority', 'all false · display-only'),
            const SizedBox(height: 8),
            if (decisions.isEmpty)
              const LocalizedText('No registry candidates.')
            else
              for (final decision in decisions)
                ListTile(
                  key: ValueKey(
                    'forge-registry-placement-${decision.deviceID}-${decision.instanceID}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('${decision.deviceID} · ${decision.instanceID}'),
                  subtitle: Text(
                    'revision=${decision.revision} · generation=${decision.generation} · heartbeat=${decision.heartbeatSequence}\n'
                    'reservation=${decision.reservationState} · '
                    'GPU=${decision.gpuCount} · memory=${decision.availableGPUMemoryBytes} B\n'
                    'matches=${decision.matchesRequirements} · '
                    'reasons=${decision.exclusionReasons.isEmpty ? 'none' : decision.exclusionReasons.join(', ')}',
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
