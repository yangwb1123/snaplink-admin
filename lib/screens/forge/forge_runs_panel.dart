part of 'forge_sessions_screen.dart';

extension _ForgeRunsPanel on _ForgeSessionsScreenState {
  Widget _runPanel(BuildContext context) {
    final selected = _selected!;
    final strings = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Runs'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: strings.refresh,
                  onPressed: _loadingRuns
                      ? null
                      : () => _loadRuns(selected.conversation.id),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text(
              context.tr(
                'Run summaries contain metadata only; task content is not shown here.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_runError != null) _runErrorMessage(context, _runError!),
            if (_loadingRuns && _runs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loadingRuns && _runError == null && _runs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.tr('No runs are linked to this conversation yet.'),
                ),
              ),
            for (final run in _runs)
              ListTile(
                key: ValueKey('forge-run-${run.runID}'),
                contentPadding: EdgeInsets.zero,
                selected: run.runID == _selectedRun?.runID,
                leading: const Icon(Icons.play_circle_outline),
                title: Text(run.runID),
                subtitle: Text(
                  '${context.tr(run.status)} · '
                  '${context.tr('Prompt ID: {id}', {'id': run.promptID})}\n'
                  '${context.tr('Created: {time}', {'time': _runTime(run.createdAtMS)})} · '
                  '${context.tr('Latest sequence: {sequence}', {'sequence': run.latestSequence})}',
                ),
                isThreeLine: true,
                trailing: run.runID == _selectedRun?.runID
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: () => _selectRun(run),
              ),
            if (_hasMoreRuns)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _loadingRuns
                      ? null
                      : () => _loadRuns(
                          selected.conversation.id,
                          loadOlder: true,
                        ),
                  icon: const Icon(Icons.expand_more),
                  label: Text(context.tr('Load older runs')),
                ),
              ),
            if (_selectedRun != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Run timeline · {id}', {
                        'id': _selectedRun!.runID,
                      }),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Reload timeline'),
                    onPressed: _loadingRunTimeline
                        ? null
                        : () => _loadRunTimeline(
                            selected.conversation.id,
                            _selectedRun!.runID,
                          ),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Text(
                context.tr(
                  'Timeline entries show event type, sequence, and time only.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_runTimelineError != null)
                _runErrorMessage(context, _runTimelineError!),
              if (_loadingRunTimeline && _runEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loadingRunTimeline &&
                  _runTimelineError == null &&
                  _runEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(context.tr('No timeline markers to show.')),
                ),
              for (final event in _runEvents)
                ListTile(
                  key: ValueKey(
                    'forge-run-event-${_selectedRun!.runID}-${event.sequence}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text(context.tr(event.type)),
                  subtitle: Text(
                    '${context.tr('Sequence: {sequence}', {'sequence': event.sequence})} · '
                    '${context.tr('Time: {time}', {'time': _runTime(event.emittedAtMS)})}',
                  ),
                ),
              if (_hasMoreRunEvents)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _loadingRunTimeline
                        ? null
                        : () => _loadRunTimeline(
                            selected.conversation.id,
                            _selectedRun!.runID,
                            loadMore: true,
                          ),
                    icon: const Icon(Icons.expand_more),
                    label: Text(context.tr('Load more timeline markers')),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _runErrorMessage(BuildContext context, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      context.tr(message),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  String _runTime(int milliseconds) => DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).toIso8601String();
}
