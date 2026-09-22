import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'agent_gpu_details.dart';

class AgentDeviceDirectory extends StatelessWidget {
  final List<AgentDevice> devices;
  final String projectId;
  final bool loading;
  final bool hasMore;
  final bool needsScope;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onSignIn;

  const AgentDeviceDirectory({
    super.key,
    required this.devices,
    required this.projectId,
    required this.loading,
    required this.hasMore,
    required this.needsScope,
    required this.error,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  strings.translate('Compute devices'),
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
        ),
        if (projectId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.tr('Project: {project}', {'project': projectId}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (needsScope)
          _scopeNotice(context)
        else if (error != null)
          _errorNotice(context)
        else if (loading && devices.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (devices.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    'No compute devices are available for this project.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: devices.length,
              itemBuilder: (context, index) =>
                  _deviceTile(context, devices[index]),
            ),
          ),
        if (hasMore && !needsScope)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(context.tr('Load more devices')),
            ),
          ),
      ],
    );
  }

  Widget _scopeNotice(BuildContext context) => Expanded(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Device access requires additional Agent permissions.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onSignIn,
              child: Text(context.tr('Sign in for Agent access')),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _errorNotice(BuildContext context) => Expanded(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr(error!)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onRefresh,
              child: Text(context.tr('Retry')),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _deviceTile(BuildContext context, AgentDevice device) {
    final strings = AppStrings.of(context);
    final status = device.availability;
    final label = switch (status) {
      'offline' => strings.translate('Offline'),
      'busy' => strings.translate('Busy'),
      'schedulable' => strings.translate('Available'),
      _ => strings.translate('No resources'),
    };
    final memory =
        '${_gib(device.availableMemoryBytes)} / '
        '${_gib(device.totalMemoryBytes)} GiB';
    final platform = [
      device.os,
      device.architecture,
    ].where((value) => value.isNotEmpty).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  device.online ? Icons.memory : Icons.cloud_off_outlined,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.name.isEmpty ? device.deviceId : device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(label: Text(label), visualDensity: VisualDensity.compact),
              ],
            ),
            Text(
              context.tr('Device: {id}', {'id': device.deviceId}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (device.instanceId.isNotEmpty)
              Text(
                context.tr('Device instance: {instance}', {
                  'instance': device.instanceId,
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              context.tr('CPU: {free} of {total} cores free', {
                'free': '${device.freeCpuCores}',
                'total': '${device.cpuCores}',
              }),
            ),
            Text(
              context.tr('Memory available / total: {memory}', {
                'memory': memory,
              }),
            ),
            Text(
              context.tr('Running tasks: {count}', {
                'count': '${device.runningTasks}',
              }),
            ),
            AgentDeviceGpuDetails(device: device),
            if (device.workspaceSupported)
              Text(context.tr('Workspace snapshots supported')),
            if (platform.isNotEmpty)
              Text(context.tr('Platform: {platform}', {'platform': platform})),
            if (device.runtimes.isNotEmpty)
              Text(
                context.tr('Runtimes: {runtimes}', {
                  'runtimes': device.runtimes.join(', '),
                }),
              ),
            if (device.lifecycleState.isNotEmpty)
              Text(
                context.tr('Lifecycle: {state}', {
                  'state': strings.translate(device.lifecycleState),
                }),
              ),
            if (device.lastSeen != null)
              Text(
                context.tr('Last seen: {time}', {
                  'time': device.lastSeen!
                      .toLocal()
                      .toString()
                      .split('.')
                      .first,
                }),
              ),
          ],
        ),
      ),
    );
  }
}

String _gib(int bytes) => (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
