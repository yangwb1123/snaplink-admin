import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'agent_compute_task_tile.dart';
import 'agent_compute_resource_fields.dart';

class AgentComputeTasksPanel extends StatelessWidget {
  final List<AgentDevice> devices;
  final List<AgentComputeTask> tasks;
  final String targetDeviceId;
  final bool loading;
  final bool hasMore;
  final bool submitting;
  final bool readScopeMissing;
  final bool writeScopeMissing;
  final bool cancelScopeMissing;
  final String? error;
  final String? formError;
  final Set<String> cancellingIds;
  final Set<String> loadingDetailIds;
  final Map<String, AgentComputeTask> taskDetails;
  final TextEditingController argvController;
  final TextEditingController workdirController;
  final TextEditingController cpuController;
  final TextEditingController memoryController;
  final TextEditingController gpuCountController;
  final TextEditingController gpuMemoryController;
  final TextEditingController timeoutController;
  final TextEditingController osController;
  final TextEditingController architectureController;
  final TextEditingController runtimesController;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onSubmit;
  final ValueChanged<AgentComputeTask> onCancel;
  final ValueChanged<String> onLoadDetails;
  final VoidCallback onSignIn;

  final bool workspaceEnabled;
  final Widget? workspaceForm;
  final Widget Function(AgentComputeTask)? workspaceDetailsBuilder;

  const AgentComputeTasksPanel({
    super.key,
    this.workspaceEnabled = false,
    this.workspaceForm,
    this.workspaceDetailsBuilder,
    required this.devices,
    required this.tasks,
    required this.targetDeviceId,
    required this.loading,
    required this.hasMore,
    required this.submitting,
    required this.readScopeMissing,
    required this.writeScopeMissing,
    required this.cancelScopeMissing,
    required this.error,
    required this.formError,
    required this.cancellingIds,
    required this.loadingDetailIds,
    required this.taskDetails,
    required this.argvController,
    required this.workdirController,
    required this.cpuController,
    required this.memoryController,
    required this.gpuCountController,
    required this.gpuMemoryController,
    required this.timeoutController,
    required this.osController,
    required this.architectureController,
    required this.runtimesController,
    required this.onTargetChanged,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onSubmit,
    required this.onCancel,
    required this.onLoadDetails,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.translate('Compute tasks'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: strings.refresh,
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (error != null) _messageCard(context, error!, onRetry: onRefresh),
        if (readScopeMissing) _scopeCard(context, 'Task read access'),
        if (cancelScopeMissing) _scopeCard(context, 'Task cancellation access'),
        _taskForm(context),
        const SizedBox(height: 16),
        Text(
          context.tr('Submitted tasks'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (loading && tasks.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (tasks.isEmpty && !readScopeMissing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              context.tr(
                'No compute tasks have been submitted for this session.',
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final task in tasks)
            AgentComputeTaskTile(
              task: taskDetails[task.taskId] ?? task,
              workspaceDetails: workspaceDetailsBuilder?.call(
                taskDetails[task.taskId] ?? task,
              ),
              loadingDetails: loadingDetailIds.contains(task.taskId),
              cancelling: cancellingIds.contains(task.taskId),
              cancelScopeMissing: cancelScopeMissing,
              onCancel: () => onCancel(task),
              onExpansionChanged: (expanded) {
                if (expanded) onLoadDetails(task.taskId);
              },
              onSignIn: onSignIn,
            ),
        if (hasMore)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(context.tr('Load more tasks')),
            ),
          ),
      ],
    );
  }

  Widget _taskForm(BuildContext context) {
    final strings = AppStrings.of(context);
    final eligible = devices
        .where(
          (device) =>
              device.online &&
              device.schedulable &&
              (!workspaceEnabled || device.workspaceSupported),
        )
        .toList(growable: false);
    final options = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text(context.tr('Automatic device selection')),
      ),
      for (final device in eligible)
        DropdownMenuItem(
          value: device.deviceId,
          child: Text(
            device.name.isEmpty ? device.deviceId : device.name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    final validTarget = eligible.any(
      (device) => device.deviceId == targetDeviceId,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Run a compute task'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (writeScopeMissing)
              _scopeCard(context, 'Task submission access'),
            TextField(
              controller: argvController,
              enabled: !writeScopeMissing && !submitting,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: strings.translate('Arguments'),
                hintText: strings.translate(
                  'One argument per line, or a JSON string array.',
                ),
                helperMaxLines: 3,
                helperText: strings.translate(
                  'Arguments are passed directly; shell parsing is not used.',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ?workspaceForm,
            if (!workspaceEnabled)
              TextField(
                controller: workdirController,
                enabled: !writeScopeMissing && !submitting,
                decoration: InputDecoration(
                  labelText: strings.translate('Relative workdir'),
                  helperMaxLines: 3,
                  helperText: strings.translate(
                    'Relative to the operator-configured project workspace.',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 8),
            AgentComputeResourceFields(
              cpuController: cpuController,
              memoryController: memoryController,
              timeoutController: timeoutController,
              gpuCountController: gpuCountController,
              gpuMemoryController: gpuMemoryController,
              enabled: !writeScopeMissing && !submitting,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: validTarget ? targetDeviceId : '',
              decoration: InputDecoration(
                labelText: strings.translate('Target device'),
                border: const OutlineInputBorder(),
              ),
              items: options,
              onChanged: writeScopeMissing || submitting
                  ? null
                  : (value) => onTargetChanged(value ?? ''),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _textField(context, osController, 'Required OS'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _textField(
                    context,
                    architectureController,
                    'Architecture',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: runtimesController,
              enabled: !writeScopeMissing && !submitting,
              decoration: InputDecoration(
                labelText: strings.translate('Required runtimes'),
                hintText: strings.translate('One runtime per line.'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (formError != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(formError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: writeScopeMissing || submitting || eligible.isEmpty
                    ? null
                    : onSubmit,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  context.tr(submitting ? 'Submitting task...' : 'Queue task'),
                ),
              ),
            ),
            if (eligible.isEmpty && !writeScopeMissing)
              Text(
                context.tr(
                  workspaceEnabled
                      ? 'No online device supports workspace snapshots.'
                      : 'No online schedulable device is available.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) => TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: AppStrings.of(context).translate(label),
      border: const OutlineInputBorder(),
    ),
  );

  Widget _scopeCard(BuildContext context, String access) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('{access} requires additional Agent permissions.', {
                'access': context.tr(access),
              }),
            ),
          ),
          TextButton(onPressed: onSignIn, child: Text(context.tr('Sign in'))),
        ],
      ),
    ),
  );

  Widget _messageCard(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(child: Text(context.tr(message))),
          IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ],
      ),
    ),
  );
}
