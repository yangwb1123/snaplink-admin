import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'agent_session_detail.dart';
import 'agent_session_list.dart';
import 'agent_device_directory.dart';
import 'agent_compute_tasks_panel.dart';

part 'agent_operations_view_placeholder.dart';

class AgentOperationsView extends StatelessWidget {
  final List<AgentInstance> instances;
  final List<AgentSession> sessions;
  final List<AgentSessionEvent> events;
  final String instanceFilter;
  final AgentSession? selectedSession;
  final AgentTurn? turn;
  final String? pendingPrompt;
  final String? promptError;
  final String? directoryError;
  final String? activityError;
  final bool directoryLoading;
  final bool instancesHaveMore;
  final bool sessionsHaveMore;
  final bool activityLoading;
  final bool sending;
  final bool cancelling;
  final bool unauthorized;
  final bool needsAgentScope;
  final bool showSessionOnNarrowScreen;
  final bool canControl;
  final TextEditingController promptController;
  final List<AgentDevice> devices;
  final bool deviceLoading;
  final bool devicesHaveMore;
  final String? deviceError;
  final bool deviceScopeMissing;
  final List<AgentComputeTask> computeTasks;
  final bool computeTaskLoading;
  final bool computeTasksHaveMore;
  final String? computeTaskError;
  final String? computeFormError;
  final String? computeTaskActionError;
  final bool taskReadScopeMissing;
  final bool taskWriteScopeMissing;
  final bool taskCancelScopeMissing;
  final bool taskRescheduleScopeMissing;
  final bool taskRetryScopeMissing;
  final String targetDeviceId;
  final bool submittingTask;
  final Set<String> cancellingTaskIds;
  final Set<String> reschedulingTaskIds;
  final Set<String> retryingTaskIds;
  final Set<String> loadingTaskDetails;
  final Map<String, AgentComputeTask> taskDetails;
  final TextEditingController computeArgvController;
  final TextEditingController computeWorkdirController;
  final TextEditingController computeCpuController;
  final TextEditingController computeMemoryController;
  final TextEditingController computeGpuCountController;
  final TextEditingController computeGpuMemoryController;
  final TextEditingController computeTimeoutController;
  final TextEditingController computeOsController;
  final TextEditingController computeArchitectureController;
  final TextEditingController computeRuntimesController;
  final Future<void> Function(String?) instanceChanged;
  final VoidCallback onRefresh;
  final ValueChanged<AgentSession> onSelectSession;
  final VoidCallback onBackToList;
  final VoidCallback onSendPrompt;
  final VoidCallback onRetryPrompt;
  final VoidCallback onCancelTurn;
  final VoidCallback onSignIn;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetryDirectory;
  final VoidCallback onRetryActivity;
  final VoidCallback onLoadMoreDirectory;
  final VoidCallback onRefreshDevices;
  final VoidCallback onLoadMoreDevices;
  final VoidCallback onRefreshTasks;
  final VoidCallback onLoadMoreTasks;
  final ValueChanged<String> onTargetDeviceChanged;
  final VoidCallback onSubmitTask;
  final ValueChanged<AgentComputeTask> onCancelTask;
  final ValueChanged<AgentComputeTask> onRescheduleTask;
  final ValueChanged<AgentComputeTask> onRetryTask;
  final ValueChanged<String> onLoadTaskDetails;

  final bool workspaceEnabled;
  final Widget? workspaceForm;
  final Widget? sessionCreation;
  final Widget? sessionClosure;
  final bool sessionWorkBlocked;
  final Widget Function(AgentComputeTask)? workspaceDetailsBuilder;

  const AgentOperationsView({
    super.key,
    this.workspaceEnabled = false,
    this.workspaceForm,
    this.sessionCreation,
    this.sessionClosure,
    this.sessionWorkBlocked = false,
    this.workspaceDetailsBuilder,
    required this.instances,
    required this.sessions,
    required this.events,
    required this.instanceFilter,
    required this.selectedSession,
    required this.turn,
    required this.pendingPrompt,
    required this.promptError,
    required this.directoryError,
    required this.activityError,
    required this.directoryLoading,
    required this.instancesHaveMore,
    required this.sessionsHaveMore,
    required this.activityLoading,
    required this.sending,
    required this.cancelling,
    required this.unauthorized,
    required this.needsAgentScope,
    required this.showSessionOnNarrowScreen,
    required this.canControl,
    required this.promptController,
    required this.devices,
    required this.deviceLoading,
    required this.devicesHaveMore,
    required this.deviceError,
    required this.deviceScopeMissing,
    required this.computeTasks,
    required this.computeTaskLoading,
    required this.computeTasksHaveMore,
    required this.computeTaskError,
    required this.computeFormError,
    required this.computeTaskActionError,
    required this.taskReadScopeMissing,
    required this.taskWriteScopeMissing,
    required this.taskCancelScopeMissing,
    required this.taskRescheduleScopeMissing,
    required this.taskRetryScopeMissing,
    required this.targetDeviceId,
    required this.submittingTask,
    required this.cancellingTaskIds,
    required this.reschedulingTaskIds,
    required this.retryingTaskIds,
    required this.loadingTaskDetails,
    required this.taskDetails,
    required this.computeArgvController,
    required this.computeWorkdirController,
    required this.computeCpuController,
    required this.computeMemoryController,
    required this.computeGpuCountController,
    required this.computeGpuMemoryController,
    required this.computeTimeoutController,
    required this.computeOsController,
    required this.computeArchitectureController,
    required this.computeRuntimesController,
    required this.instanceChanged,
    required this.onRefresh,
    required this.onSelectSession,
    required this.onBackToList,
    required this.onSendPrompt,
    required this.onRetryPrompt,
    required this.onCancelTurn,
    required this.onSignIn,
    required this.onOpenSettings,
    required this.onRetryDirectory,
    required this.onRetryActivity,
    required this.onLoadMoreDirectory,
    required this.onRefreshDevices,
    required this.onLoadMoreDevices,
    required this.onRefreshTasks,
    required this.onLoadMoreTasks,
    required this.onTargetDeviceChanged,
    required this.onSubmitTask,
    required this.onCancelTask,
    required this.onRescheduleTask,
    required this.onRetryTask,
    required this.onLoadTaskDetails,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading:
            MediaQuery.sizeOf(context).width < 840 && showSessionOnNarrowScreen
            ? BackButton(onPressed: onBackToList)
            : null,
        title: Text(context.tr('Agent Operations')),
        actions: [
          IconButton(
            tooltip: context.tr('Forge Sessions'),
            onPressed: () => BrowserNavigation.assignLocation('/forge/'),
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            tooltip: strings.refresh,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: strings.settings,
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: unauthorized || needsAgentScope
          ? _authorizationRequired(context)
          : LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 840;
                final list = _directoryTabs(context);
                final detail = _sessionDetail(context);
                if (narrow) {
                  return showSessionOnNarrowScreen ? detail : list;
                }
                return Row(
                  children: [
                    SizedBox(width: 360, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(child: detail),
                  ],
                );
              },
            ),
    );
  }

  Widget _sessionList() => AgentSessionList(
    sessionCreation: sessionCreation,
    instances: instances,
    sessions: sessions,
    instanceFilter: instanceFilter,
    selectedSessionId: selectedSession?.sessionId,
    loading: directoryLoading,
    error: directoryError,
    onInstanceChanged: instanceChanged,
    onRefresh: onRetryDirectory,
    onSelectSession: onSelectSession,
    instancesHaveMore: instancesHaveMore,
    sessionsHaveMore: sessionsHaveMore,
    onLoadMore: onLoadMoreDirectory,
  );

  Widget _directoryTabs(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        TabBar(
          tabs: [
            Tab(text: context.tr('Sessions')),
            Tab(text: context.tr('Compute devices')),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _sessionList(),
              AgentDeviceDirectory(
                devices: devices,
                projectId: selectedSession?.projectId ?? '',
                loading: deviceLoading,
                hasMore: devicesHaveMore,
                needsScope: deviceScopeMissing,
                error: deviceError,
                onRefresh: onRefreshDevices,
                onLoadMore: onLoadMoreDevices,
                onSignIn: onSignIn,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sessionDetail(BuildContext context) {
    final session = selectedSession;
    if (session == null) {
      return const _SelectSessionPlaceholder();
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          ?sessionClosure,
          TabBar(
            tabs: [
              Tab(text: context.tr('Activity')),
              Tab(text: context.tr('Compute tasks')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                AgentSessionDetail(
                  key: ValueKey('activity-${session.sessionId}'),
                  session: session,
                  events: events,
                  turn: turn,
                  loading: activityLoading,
                  error: activityError,
                  canControl: canControl,
                  sending: sending,
                  cancelling: cancelling,
                  pendingPrompt: pendingPrompt,
                  promptError: promptError,
                  promptController: promptController,
                  onSendPrompt: onSendPrompt,
                  onRetryPrompt: onRetryPrompt,
                  onCancelTurn: onCancelTurn,
                  onRetry: onRetryActivity,
                ),
                AgentComputeTasksPanel(
                  sessionReadOnly: sessionWorkBlocked,
                  key: ValueKey('compute-${session.sessionId}'),
                  workspaceEnabled: workspaceEnabled,
                  workspaceForm: workspaceForm,
                  workspaceDetailsBuilder: workspaceDetailsBuilder,
                  devices: devices,
                  tasks: computeTasks,
                  targetDeviceId: targetDeviceId,
                  loading: computeTaskLoading,
                  hasMore: computeTasksHaveMore,
                  submitting: submittingTask,
                  readScopeMissing: taskReadScopeMissing,
                  writeScopeMissing: taskWriteScopeMissing,
                  cancelScopeMissing: taskCancelScopeMissing,
                  rescheduleScopeMissing: taskRescheduleScopeMissing,
                  retryScopeMissing: taskRetryScopeMissing,
                  error: computeTaskActionError ?? computeTaskError,
                  formError: computeFormError,
                  cancellingIds: cancellingTaskIds,
                  reschedulingIds: reschedulingTaskIds,
                  retryingIds: retryingTaskIds,
                  loadingDetailIds: loadingTaskDetails,
                  taskDetails: taskDetails,
                  argvController: computeArgvController,
                  workdirController: computeWorkdirController,
                  cpuController: computeCpuController,
                  memoryController: computeMemoryController,
                  gpuCountController: computeGpuCountController,
                  gpuMemoryController: computeGpuMemoryController,
                  timeoutController: computeTimeoutController,
                  osController: computeOsController,
                  architectureController: computeArchitectureController,
                  runtimesController: computeRuntimesController,
                  onTargetChanged: onTargetDeviceChanged,
                  onRefresh: onRefreshTasks,
                  onLoadMore: onLoadMoreTasks,
                  onSubmit: onSubmitTask,
                  onCancel: onCancelTask,
                  onReschedule: onRescheduleTask,
                  onRetry: onRetryTask,
                  onLoadDetails: onLoadTaskDetails,
                  onSignIn: onSignIn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _authorizationRequired(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              context.tr(
                'This sign-in is not authorized for Agent Hub. Sign in again to request access.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login),
              label: Text(context.tr('Sign in for Agent access')),
            ),
          ],
        ),
      ),
    ),
  );
}
