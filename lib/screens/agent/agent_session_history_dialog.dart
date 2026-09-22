import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/api/agent_session_operation_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'agent_session_history.dart';

class AgentSessionHistoryDialog extends StatefulWidget {
  final AgentHubApi api;
  final String instanceId;
  final String instanceName;
  final bool Function() canOpen;
  final bool Function() isAuthorized;
  final ValueChanged<AgentSession> onOpen;

  const AgentSessionHistoryDialog({
    super.key,
    required this.api,
    required this.instanceId,
    required this.instanceName,
    required this.canOpen,
    required this.isAuthorized,
    required this.onOpen,
  });

  @override
  State<AgentSessionHistoryDialog> createState() =>
      _AgentSessionHistoryDialogState();
}

class _AgentSessionHistoryDialogState extends State<AgentSessionHistoryDialog> {
  late final AgentSessionHistory _history;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _history = AgentSessionHistory(
      widget.api,
      widget.instanceId,
      isAuthorized: widget.isAuthorized,
    );
    unawaited(_history.load());
  }

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!widget.canOpen()) return;
    final request = _history.selected;
    final session = await _history.openSelected();
    if (!mounted ||
        _dismissed ||
        session == null ||
        _history.selected != request ||
        !widget.canOpen() ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    widget.onOpen(session);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _dismissed = true;
    },
    child: ListenableBuilder(
      listenable: _history,
      builder: (context, _) => AlertDialog(
        title: Text(context.tr('Session requests')),
        content: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.instanceName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.instanceId,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Accepted requests only. Refresh to see changes. Local unconfirmed requests are tracked separately.',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('history-latest'),
                    onPressed: _history.busy ? null : () => _history.load(),
                    child: Text(context.tr('Refresh latest')),
                  ),
                  OutlinedButton(
                    key: const ValueKey('history-older'),
                    onPressed:
                        _history.busy ||
                            (_history.page?.nextCursor.isEmpty ?? true)
                        ? null
                        : () =>
                              _history.load(before: _history.page!.nextCursor),
                    child: Text(context.tr('Older requests')),
                  ),
                ],
              ),
              if (_history.busy) const LinearProgressIndicator(),
              Expanded(child: _body(context)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _dismissed = true;
              Navigator.pop(context);
            },
            child: Text(context.tr('Dismiss')),
          ),
        ],
      ),
    ),
  );

  Widget _body(BuildContext context) {
    final items = _history.page?.items ?? <AgentSessionOperation>[];
    return ListView.builder(
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _pageHeader(context);
        final request = items[index - 1];
        return ListTile(
          key: ValueKey('history-row-${request.identity}'),
          selected: _history.selected?.identity == request.identity,
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.tr(
              request.operation == 'create'
                  ? 'Create session'
                  : 'Close session',
            ),
          ),
          subtitle: Text(
            '${request.name.isEmpty ? request.sessionId : request.name}\n${context.tr(historyStatus(request))}\n${request.requestId}',
          ),
          onTap: () => _history.select(request),
        );
      },
    );
  }

  Widget _pageHeader(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_history.error != null) ...[
        const SizedBox(height: 8),
        Text(context.tr(_history.error!)),
        if (_history.page == null && !_history.unsupported)
          TextButton(
            onPressed: _history.busy ? null : _history.retryPage,
            child: Text(context.tr('Retry')),
          ),
      ],
      if (_history.page?.items.isEmpty == true)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            context.tr('No accepted session requests for this instance.'),
          ),
        ),
      if (_history.selected case final request?) _details(context, request),
    ],
  );

  Widget _details(BuildContext context, AgentSessionOperation request) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Request details'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            context.tr(
              request.operation == 'create'
                  ? 'Create session'
                  : 'Close session',
            ),
          ),
          Text(context.tr(historyStatus(request))),
          if (request.name.isNotEmpty) Text(request.name),
          Text('${context.tr('Request ID')}: ${request.requestId}'),
          if (request.sessionId.isNotEmpty)
            Text('${context.tr('Session ID')}: ${request.sessionId}'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const ValueKey('history-refresh-detail'),
                onPressed: _history.busy ? null : _history.refreshSelected,
                child: Text(context.tr('Refresh request')),
              ),
              if (request.sessionId.isNotEmpty)
                FilledButton(
                  key: const ValueKey('history-open'),
                  onPressed: _history.busy || !widget.canOpen() ? null : _open,
                  child: Text(context.tr('Open session')),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
