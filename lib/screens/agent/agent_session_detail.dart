import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'agent_event_timeline.dart';

class AgentSessionDetail extends StatelessWidget {
  final AgentSession session;
  final List<AgentSessionEvent> events;
  final AgentTurn? turn;
  final bool loading;
  final String? error;
  final bool canControl;
  final bool sending;
  final bool cancelling;
  final String? pendingPrompt;
  final String? promptError;
  final TextEditingController promptController;
  final VoidCallback onSendPrompt;
  final VoidCallback onRetryPrompt;
  final VoidCallback onCancelTurn;
  final VoidCallback onRetry;

  const AgentSessionDetail({
    super.key,
    required this.session,
    required this.events,
    required this.turn,
    required this.loading,
    required this.error,
    required this.canControl,
    required this.sending,
    required this.cancelling,
    required this.pendingPrompt,
    required this.promptError,
    required this.promptController,
    required this.onSendPrompt,
    required this.onRetryPrompt,
    required this.onCancelTurn,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        if (!canControl)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(
                          session.controllable
                              ? 'The selected instance is offline.'
                              : 'This session cannot be controlled from this account or instance.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (turn != null) _turnStatus(context, turn!),
        Expanded(
          child: error != null
              ? ErrorStateView(message: context.tr(error!), onRetry: onRetry)
              : loading && events.isEmpty
              ? AsyncView<List<AgentSessionEvent>>(
                  loading: true,
                  data: events,
                  dataBuilder: (_) => const SizedBox.shrink(),
                )
              : AgentTimelineView(items: buildAgentTimeline(events)),
        ),
        _composer(context, strings),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name.isNotEmpty
                      ? session.name
                      : session.localSessionId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.projectId.isEmpty ? session.instanceId : session.projectId} · ${session.status}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _turnStatus(BuildContext context, AgentTurn current) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Turn {id} · {state}', {
                    'id': current.turnId,
                    'state': current.state,
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (current.isActive)
                TextButton.icon(
                  onPressed: cancelling ? null : onCancelTurn,
                  icon: cancelling
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: Text(strings.translate('Cancel turn')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(BuildContext context, AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    final retry = pendingPrompt != null;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (promptError != null) ...[
                Text(
                  context.tr(promptError!),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
                const SizedBox(height: 8),
              ],
              if (retry) ...[
                Text(
                  context.tr(
                    'The previous send was not confirmed. Retry uses the same prompt and request key.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: promptController,
                      readOnly: retry,
                      enabled: canControl && turn?.isActive != true && !sending,
                      minLines: 2,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: strings.translate('Prompt'),
                        hintText: strings.translate('Enter a prompt to send.'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: !canControl || turn?.isActive == true || sending
                        ? null
                        : retry
                        ? onRetryPrompt
                        : onSendPrompt,
                    icon: sending
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(retry ? Icons.replay : Icons.send),
                    label: Text(
                      context.tr(
                        sending
                            ? 'Sending...'
                            : retry
                            ? 'Retry send'
                            : 'Send prompt',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
