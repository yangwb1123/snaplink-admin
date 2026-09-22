import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/status_chip.dart';

class AgentSessionList extends StatelessWidget {
  final List<AgentInstance> instances;
  final List<AgentSession> sessions;
  final String instanceFilter;
  final String? selectedSessionId;
  final bool loading;
  final bool instancesHaveMore;
  final bool sessionsHaveMore;
  final String? error;
  final Widget? sessionCreation;
  final void Function(String?) onInstanceChanged;
  final VoidCallback onRefresh;
  final ValueChanged<AgentSession> onSelectSession;
  final VoidCallback onLoadMore;

  const AgentSessionList({
    super.key,
    required this.instances,
    required this.sessions,
    required this.instanceFilter,
    required this.selectedSessionId,
    required this.loading,
    required this.instancesHaveMore,
    required this.sessionsHaveMore,
    required this.error,
    this.sessionCreation,
    required this.onInstanceChanged,
    required this.onRefresh,
    required this.onSelectSession,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  strings.translate('Instances'),
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
        if (instancesHaveMore)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(strings.translate('Load more instances')),
            ),
          ),
        if (instances.isEmpty && !loading && error == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.tr('No instances are registered with Agent Hub.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            initialValue: instanceFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: strings.translate('All instances'),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(strings.translate('All instances')),
              ),
              for (final instance in instances)
                DropdownMenuItem(
                  value: instance.instanceId,
                  child: Text(
                    '${instance.name.isEmpty ? instance.instanceId : '${instance.name} · ${instance.instanceId}'} · '
                    '${context.tr(instance.online ? 'Online' : 'Offline')}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onInstanceChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            strings.translate('Sessions'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ?sessionCreation,
        Expanded(
          child: AsyncView<List<AgentSession>>(
            loading: loading,
            error: error,
            data: sessions,
            onRetry: onRefresh,
            emptyTitle: 'No sessions found for this instance.',
            dataBuilder: (values) => ListView.builder(
              itemCount: values.length,
              itemBuilder: (context, index) {
                final session = values[index];
                final selected = session.sessionId == selectedSessionId;
                final scope = [
                  context.tr('Instance: {id}', {'id': session.instanceId}),
                  if (session.projectId.isNotEmpty)
                    context.tr('Project: {project}', {
                      'project': session.projectId,
                    }),
                ].join(' · ');
                return ListTile(
                  selected: selected,
                  selectedTileColor: AppColors.accentBlue.withValues(
                    alpha: 0.10,
                  ),
                  leading: Icon(
                    session.controllable
                        ? Icons.chat_bubble_outline
                        : Icons.visibility_outlined,
                  ),
                  title: Text(
                    session.name.isNotEmpty
                        ? session.name
                        : session.localSessionId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$scope · ${session.status}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: session.controllable
                      ? null
                      : StatusChip.inactive(label: 'Read-only'),
                  onTap: () => onSelectSession(session),
                );
              },
            ),
          ),
        ),
        if (sessionsHaveMore)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(strings.translate('Load more sessions')),
            ),
          ),
      ],
    );
  }
}
