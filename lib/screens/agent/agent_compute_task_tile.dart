import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'agent_gpu_details.dart';

class AgentComputeTaskTile extends StatelessWidget {
  final AgentComputeTask task;
  final Widget? workspaceDetails;
  final bool loadingDetails;
  final bool cancelling;
  final bool cancelScopeMissing;
  final bool rescheduling;
  final bool rescheduleScopeMissing;
  final bool retrying;
  final bool retryScopeMissing;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;
  final VoidCallback? onRetry;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onSignIn;

  const AgentComputeTaskTile({
    super.key,
    this.workspaceDetails,
    required this.task,
    required this.loadingDetails,
    required this.cancelling,
    required this.cancelScopeMissing,
    required this.rescheduling,
    required this.rescheduleScopeMissing,
    this.retrying = false,
    this.retryScopeMissing = false,
    required this.onCancel,
    required this.onReschedule,
    this.onRetry,
    required this.onExpansionChanged,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = _taskStateLabel(strings, task.state);
    return Card(
      child: ExpansionTile(
        onExpansionChanged: onExpansionChanged,
        leading: Icon(_taskIcon(task.state)),
        title: Text(
          context.tr('Task {id} · {state}', {
            'id': task.taskId,
            'state': state,
          }),
        ),
        subtitle: Text(
          context.tr('Device: {device} · {actor}', {
            'device': task.deviceId.isEmpty
                ? (task.targetDeviceId.isEmpty
                      ? strings.translate('Automatic')
                      : task.targetDeviceId)
                : task.deviceId,
            'actor': task.actor.isEmpty
                ? strings.translate('unknown')
                : task.actor,
          }),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.canCancel)
              IconButton(
                tooltip: strings.translate('Cancel task'),
                onPressed: cancelling || cancelScopeMissing ? null : onCancel,
                icon: cancelling
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop_circle_outlined),
              ),
            if (task.canReschedule)
              IconButton(
                tooltip: strings.translate('Reschedule task'),
                onPressed: rescheduling || rescheduleScopeMissing
                    ? null
                    : onReschedule,
                icon: rescheduling
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.alt_route),
              ),
            if (task.canRetry && onRetry != null)
              IconButton(
                tooltip: strings.translate('Retry lost task (duplicate risk)'),
                onPressed: retrying || retryScopeMissing ? null : onRetry,
                icon: retrying
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.replay_circle_filled_outlined),
              ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (cancelScopeMissing) _scopeCard(context, onSignIn),
          if (retryScopeMissing) _scopeCard(context, onSignIn),
          if (loadingDetails)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            )
          else
            _details(context),
        ],
      ),
    );
  }

  Widget _details(BuildContext context) {
    final strings = AppStrings.of(context);
    final result = task.result;
    final artifact = task.artifactRef;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detail(context, 'Actor', task.actor),
          _detail(context, 'Project', task.projectId),
          _detail(context, 'Device instance', task.deviceInstanceId),
          _detail(context, 'Workdir', task.workdir),
          _detail(
            context,
            'Arguments',
            task.argv.map((item) => item).join(' · '),
          ),
          _detail(context, 'Requested CPU', '${task.resources.cpuCores}'),
          _detail(
            context,
            'Requested memory (MiB)',
            '${task.resources.memoryBytes ~/ (1024 * 1024)}',
          ),
          AgentTaskGpuDetails(task: task),
          _detail(context, 'Requirements', _requirements(task.requirements)),
          if (task.error.isNotEmpty) _detail(context, 'Task error', task.error),
          if (result != null) ...[
            _detail(context, 'Exit code', result.exitCode?.toString() ?? '—'),
            _detail(
              context,
              'Elapsed seconds',
              result.elapsed.toStringAsFixed(2),
            ),
            if (result.timedOut) Text(context.tr('Task timed out.')),
            if (result.cancelled) Text(context.tr('Execution cancelled.')),
            if (result.stdout.isNotEmpty)
              _output(context, 'Standard output', result.stdout),
            if (result.stderr.isNotEmpty)
              _output(context, 'Standard error', result.stderr),
            if (result.outputTruncated)
              Text(context.tr('Execution output was truncated.')),
            if (result.displayTruncated)
              Text(
                context.tr('Output display is limited to 64 KiB per stream.'),
              ),
            if (result.evidenceDigest.isNotEmpty)
              _detail(context, 'Evidence digest', result.evidenceDigest),
          ],
          _detail(
            context,
            'Vault archive',
            _archiveState(strings, task.archiveState),
          ),
          if (artifact != null) ...[
            _detail(context, 'Artifact bucket', artifact.bucket),
            _detail(context, 'Artifact key', artifact.key),
            _detail(context, 'Artifact version', artifact.versionId),
            _detail(context, 'Artifact SHA-256', artifact.sha256),
            _detail(context, 'Artifact size (bytes)', '${artifact.size}'),
          ],
          ?workspaceDetails,
          _detail(context, 'Updated', _dateLabel(task.updatedAt)),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) =>
      value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            context.tr('{label}: {value}', {
              'label': context.tr(label),
              'value': value,
            }),
          ),
        );

  Widget _output(BuildContext context, String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(label),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SelectableText(value),
        ],
      ),
    ),
  );

  Widget _scopeCard(
    BuildContext context,
    VoidCallback onSignIn, {
    String message =
        'Task cancellation access requires additional Agent permissions.',
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(context.tr(message))),
          TextButton(onPressed: onSignIn, child: Text(context.tr('Sign in'))),
        ],
      ),
    ),
  );
}

String _taskStateLabel(AppStrings strings, String state) => switch (state) {
  'queued' => strings.translate('queued'),
  'dispatching' => strings.translate('dispatching'),
  'running' => strings.translate('running'),
  'cancel_requested' => strings.translate('Cancellation requested'),
  'completed' => strings.translate('completed'),
  'failed' => strings.translate('failed'),
  'cancelled' => strings.translate('cancelled'),
  'lost' => strings.translate('lost'),
  _ => state,
};

IconData _taskIcon(String state) => switch (state) {
  'completed' => Icons.check_circle_outline,
  'failed' || 'lost' => Icons.error_outline,
  'cancelled' || 'cancel_requested' => Icons.stop_circle_outlined,
  'running' => Icons.sync,
  _ => Icons.schedule,
};

String _archiveState(AppStrings strings, String state) => switch (state) {
  'pending' => strings.translate('pending'),
  'archived' => strings.translate('archived'),
  'failed' => strings.translate('failed'),
  _ => strings.translate('disabled'),
};

String _requirements(AgentTaskRequirements value) => [
  value.os,
  value.architecture,
  ...value.runtimes,
].where((item) => item.isNotEmpty).join(' · ');

String _dateLabel(DateTime? value) =>
    value?.toLocal().toString().split('.').first ?? '';
