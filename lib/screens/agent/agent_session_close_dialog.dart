import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'agent_session_closure.dart';

class AgentSessionCloseDialog extends StatelessWidget {
  final AgentSessionClosure closure;
  final AgentSession? target;
  final VoidCallback onSubmit;

  const AgentSessionCloseDialog({
    super.key,
    required this.closure,
    required this.target,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: closure,
    builder: (context, _) {
      final request = closure.request;
      final session = target;
      final name = closure.hasInput ? closure.name : session?.name ?? '';
      final id = closure.hasInput
          ? closure.sessionId
          : session?.sessionId ?? '';
      return AlertDialog(
        title: Text(
          context.tr(
            closure.hasInput ? 'Session close status' : 'Close session?',
          ),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(name.isEmpty ? id : name),
                if (name.isNotEmpty) Text(id),
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    'Closing stops this idle session and releases its capacity after confirmation. Its history is preserved. It cannot be reopened.',
                  ),
                ),
                if (request != null) ...[
                  const SizedBox(height: 16),
                  Text(context.tr(closureStatus(request))),
                ],
                if (closure.busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
                if (closure.error != null) ...[
                  const SizedBox(height: 16),
                  Text(context.tr(closure.error!)),
                ],
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    'Closing this dialog keeps tracking. Leaving Agent Operations, reloading, or signing in again discards this local recovery state.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr(closure.hasInput ? 'Dismiss' : 'Cancel')),
          ),
          if (closure.queued && closure.error != null)
            FilledButton(
              onPressed: closure.busy ? null : closure.refresh,
              child: Text(context.tr('Retry status')),
            ),
          if (request == null)
            FilledButton(
              onPressed: closure.busy || (!closure.hasInput && session == null)
                  ? null
                  : () {
                      if (!closure.hasInput) onSubmit();
                      closure.submit(
                        closure.hasInput
                            ? closure.sessionId
                            : session!.sessionId,
                        closure.hasInput
                            ? closure.instanceId
                            : session!.instanceId,
                        closure.hasInput ? closure.name : session!.name,
                      );
                    },
              child: Text(
                context.tr(
                  closure.hasInput ? 'Retry same request' : 'Confirm close',
                ),
              ),
            ),
        ],
      );
    },
  );
}
