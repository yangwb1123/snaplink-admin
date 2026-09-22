import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_resource_summary.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Displays the aggregate produced from an offline multi-instance inventory
/// and placement fixture. It has no API client, target-selection callback, or
/// execution authority.
class ForgeDeviceResourceSummaryPanel extends StatelessWidget {
  final ForgeDeviceResourceSummaryFixture fixture;

  const ForgeDeviceResourceSummaryPanel({super.key, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final summary = fixture.expected;
    return Card(
      key: const ValueKey('forge-device-resource-summary-preview-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Forge device resource summary'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Offline read-only aggregate; all values are unverified and no target was selected.',
              ),
            ),
            _row(context, 'Conversation', summary.conversationID),
            _row(context, 'Run', summary.runID),
            _row(context, 'Evaluated at', '${summary.evaluatedAtMS}'),
            _row(
              context,
              'Devices / Runner instances',
              '${summary.deviceCount} / ${summary.runnerInstanceCount}',
            ),
            _row(
              context,
              'Declared CPU / memory / storage',
              '${summary.availableCPUCores} / ${summary.availableMemoryBytes} B / ${summary.availableStorageBytes} B',
            ),
            _row(
              context,
              'Declared GPUs / GPU memory',
              '${summary.availableGPUCount} / ${summary.availableGPUMemoryBytes} B',
            ),
            _row(
              context,
              'Eligible devices / instances',
              '${summary.eligibleDeviceCount} / ${summary.eligibleInstanceCount}',
            ),
            _row(context, 'Selected target', 'none'),
            _row(context, 'Authority', 'all false · display-only'),
            Text(
              context.tr(
                'Every total includes only caller-declared resources.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 190, child: Text(context.tr(label))),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
