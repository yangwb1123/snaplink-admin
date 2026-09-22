import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'agent_compute_placement.dart';

class AgentComputePlacementDialog extends StatelessWidget {
  final AgentComputePlacement placement;

  const AgentComputePlacementDialog({super.key, required this.placement});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: placement,
    builder: (context, _) => AlertDialog(
      title: Text(context.tr('Task placement')),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              placement.taskId,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const ValueKey('placement-refresh'),
                  onPressed: placement.busy || placement.invalidated
                      ? null
                      : () => placement.load(),
                  child: Text(context.tr('Refresh')),
                ),
                OutlinedButton(
                  key: const ValueKey('placement-next'),
                  onPressed:
                      placement.busy ||
                          placement.invalidated ||
                          (placement.page?.nextCursor.isEmpty ?? true)
                      ? null
                      : () => placement.load(next: true),
                  child: Text(context.tr('Next devices')),
                ),
              ],
            ),
            if (placement.busy) const LinearProgressIndicator(),
            Expanded(child: _body(context)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Dismiss')),
        ),
      ],
    ),
  );

  Widget _body(BuildContext context) {
    final page = placement.page;
    final observedTime = page == null
        ? null
        : placementObservationTime(page.evaluatedAt);
    final devices = page?.devices ?? const [];
    return ListView.builder(
      itemCount: devices.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr(
                    'Live observations only. Eligibility does not reserve capacity; the execution service still decides.',
                  ),
                ),
                if (placement.error != null) ...[
                  const SizedBox(height: 8),
                  Text(context.tr(placement.error!)),
                ],
                if (page != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr('Task state: {state}', {
                      'state': context.tr(
                        page.state == 'cancel_requested'
                            ? 'Cancellation requested'
                            : page.state,
                      ),
                    }),
                  ),
                  Text(
                    observedTime == null
                        ? context.tr(
                            'Observation time is outside the displayable range.',
                          )
                        : context.tr('Observed at: {time}', {
                            'time': observedTime,
                          }),
                  ),
                  if (page.state != 'queued')
                    Text(
                      context.tr(
                        'Placement diagnostics apply only while the task is queued.',
                      ),
                    )
                  else if (devices.isEmpty)
                    Text(
                      context.tr(
                        'No visible original device bindings are available to inspect.',
                      ),
                    ),
                ],
              ],
            ),
          );
        }
        final device = devices[index - 1];
        return Card(
          key: ValueKey('placement-device-${device.deviceId}'),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(device.deviceId),
                Text(
                  context.tr('Device instance: {instance}', {
                    'instance': device.instanceId,
                  }),
                ),
                if (device.eligible)
                  Text(context.tr('Eligible in this observation'))
                else
                  for (final reason in device.reasons)
                    Text(context.tr(placementReason(reason))),
              ],
            ),
          ),
        );
      },
    );
  }
}
