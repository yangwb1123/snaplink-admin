part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenOfflineReceiptImports
    on _ForgeSessionsScreenState {
  Future<void> _importOfflineRunnerExecutionIntent() async {
    final conversationID = _selected?.conversation.id;
    final runID = _selectedRun?.runID;
    if (conversationID == null || runID == null) return;

    final controller = TextEditingController();
    try {
      final observation = await showDialog<ForgeRunnerExecutionIntentObservation>(
        context: context,
        builder: (dialogContext) {
          String? errorMessage;
          var importing = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (importing) return;
                setDialogState(() {
                  importing = true;
                  errorMessage = null;
                });
                try {
                  final raw = controller.text.trim();
                  if (raw.isEmpty || raw.length > 256 * 1024) {
                    throw const FormatException('size');
                  }
                  final parsed = ForgeRunnerExecutionIntentObservation.fromJson(
                    jsonDecode(raw),
                  );
                  if (!parsed.isFor(conversationID, runID)) {
                    throw const FormatException('run_binding');
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(parsed);
                  }
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    importing = false;
                    errorMessage =
                        'Invalid or foreign Runner execution observation.';
                  });
                }
              }

              return AlertDialog(
                title: Text(context.tr('Import Runner execution observation')),
                content: SizedBox(
                  width: min(MediaQuery.sizeOf(context).width - 48, 720),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(
                            'Paste the canonical Runner execution observation JSON for this selected Run. It is not saved or used for execution.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey(
                            'forge-runner-execution-observation-json',
                          ),
                          controller: controller,
                          autofocus: true,
                          minLines: 8,
                          maxLines: 16,
                          enabled: !importing,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'Canonical Runner execution observation JSON',
                            ),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.tr(errorMessage!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: importing
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(context.tr('Cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey(
                      'forge-import-runner-execution-observation-submit',
                    ),
                    onPressed: importing ? null : submit,
                    child: Text(context.tr('Import')),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || observation == null) return;
      if (_selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID) {
        return;
      }
      _update(() {
        _importedRunnerExecutionIntentObservation = observation;
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _importOfflineSessionRunnerReceiptObservation() async {
    final conversationID = _selected?.conversation.id;
    final runID = _selectedRun?.runID;
    if (conversationID == null || runID == null) return;

    final controller = TextEditingController();
    try {
      final observation = await showDialog<ForgeSessionRunnerReceiptObservation>(
        context: context,
        builder: (dialogContext) {
          String? errorMessage;
          var importing = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (importing) return;
                setDialogState(() {
                  importing = true;
                  errorMessage = null;
                });
                try {
                  final raw = controller.text.trim();
                  if (raw.isEmpty || raw.length > 256 * 1024) {
                    throw const FormatException('size');
                  }
                  final parsed = ForgeSessionRunnerReceiptObservation.fromJson(
                    jsonDecode(raw),
                  );
                  if (!parsed.isFor(conversationID, runID)) {
                    throw const FormatException('run_binding');
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(parsed);
                  }
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    importing = false;
                    errorMessage =
                        'Invalid or foreign session Runner receipt observation.';
                  });
                }
              }

              return AlertDialog(
                title: Text(
                  context.tr('Import session Runner receipt observation'),
                ),
                content: SizedBox(
                  width: min(MediaQuery.sizeOf(context).width - 48, 720),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(
                            'Paste the canonical session Runner receipt observation JSON for this selected Run. It is not saved or used for execution.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey(
                            'forge-session-runner-receipt-observation-json',
                          ),
                          controller: controller,
                          autofocus: true,
                          minLines: 8,
                          maxLines: 16,
                          enabled: !importing,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              'Canonical session Runner receipt observation JSON',
                            ),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.tr(errorMessage!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: importing
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(context.tr('Cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey(
                      'forge-import-session-runner-receipt-observation-submit',
                    ),
                    onPressed: importing ? null : submit,
                    child: Text(context.tr('Import')),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || observation == null) return;
      if (_selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID) {
        return;
      }
      _update(() {
        _importedSessionRunnerReceiptObservation = observation;
      });
    } finally {
      controller.dispose();
    }
  }
}
