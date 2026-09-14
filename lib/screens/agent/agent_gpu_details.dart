import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';

class AgentDeviceGpuDetails extends StatelessWidget {
  final AgentDevice device;

  const AgentDeviceGpuDetails({super.key, required this.device});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(
        context.tr('GPU status: {status}', {
          'status': context.tr(_gpuStatus(device.gpuStatus)),
        }),
      ),
      for (final gpu in device.gpus)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NVIDIA · ${gpu.name}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(context.tr('GPU UUID: {uuid}', {'uuid': gpu.uuid})),
              Text(
                context.tr('GPU memory available / total: {memory}', {
                  'memory':
                      '${_gib(gpu.availableMemoryBytes)} / '
                      '${_gib(gpu.totalMemoryBytes)} GiB',
                }),
              ),
              Text(
                context.tr('GPU scheduling: {state}', {
                  'state': context.tr(
                    gpu.reserved
                        ? 'Reserved'
                        : gpu.schedulable
                        ? 'Available'
                        : 'Unavailable',
                  ),
                }),
              ),
              Text(
                context.tr('GPU observed: {time}', {
                  'time': _date(gpu.observedAt),
                }),
              ),
            ],
          ),
        ),
    ],
  );
}

class AgentTaskGpuDetails extends StatelessWidget {
  final AgentComputeTask task;

  const AgentTaskGpuDetails({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final assignment = task.gpuAssignment;
    if (task.resources.gpuCount == 0 && assignment == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Requested GPUs: {count}', {
            'count': '${task.resources.gpuCount}',
          }),
        ),
        Text(
          context.tr('Minimum free memory per GPU: {memory} MiB', {
            'memory': '${task.resources.gpuMemoryBytes ~/ (1024 * 1024)}',
          }),
        ),
        if (assignment == null)
          Text(context.tr('GPU assignment has not been reported.'))
        else ...[
          Text(context.tr('Assigned NVIDIA physical GPUs')),
          for (final uuid in assignment.uuids)
            SelectableText(context.tr('GPU UUID: {uuid}', {'uuid': uuid})),
          Text(
            context.tr('GPU assigned: {time}', {
              'time': _date(assignment.assignedAt),
            }),
          ),
          Text(
            context.tr('GPU observed: {time}', {
              'time': _date(assignment.observedAt),
            }),
          ),
        ],
      ],
    );
  }
}

String _gpuStatus(String value) => switch (value) {
  'available' => 'Available',
  'busy' => 'Busy',
  'stale' => 'Stale GPU report',
  'unsupported' => 'Unsupported',
  _ => 'Unavailable or not reported',
};

String _gib(int value) => (value / (1024 * 1024 * 1024)).toStringAsFixed(1);
String _date(DateTime value) => value.toLocal().toString().split('.').first;
