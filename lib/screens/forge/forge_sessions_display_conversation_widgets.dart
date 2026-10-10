part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayConversationWidgets
    on _ForgeSessionsScreenState {
  Widget _createCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Create a conversation'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            enabled: !_creating && _pendingCreate == null,
            decoration: InputDecoration(
              labelText: context.tr('Title'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _scopeKind,
            decoration: InputDecoration(
              labelText: context.tr('Scope'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final kind in const ['global', 'project', 'group'])
                DropdownMenuItem(value: kind, child: Text(context.tr(kind))),
            ],
            onChanged: _creating || _pendingCreate != null
                ? null
                : _setScopeKind,
          ),
          if (_scopeKind != 'global') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _scopeIDController,
              enabled: !_creating && _pendingCreate == null,
              decoration: InputDecoration(
                labelText: context.tr('Project or group ID'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (_createError != null)
            _inlineError(context, _createError!, _signIn),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                _creating ||
                    _appending ||
                    _pendingPrompt != null ||
                    _submittingPendingRunIntent
                ? null
                : _createConversation,
            icon: _creating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(
              _pendingCreate == null
                  ? context.tr('Create conversation')
                  : context.tr('Retry create'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _conversationTile(BuildContext context, ForgeOwnedConversation item) {
    final selected = item.conversation.id == _selected?.conversation.id;
    return Card(
      child: ListTile(
        key: ValueKey('forge-conversation-${item.conversation.id}'),
        selected: selected,
        title: Text(
          item.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(item.conversation.scope.label),
        trailing: selected ? const Icon(Icons.chevron_right) : null,
        onTap:
            _appending || _pendingPrompt != null || _submittingPendingRunIntent
            ? null
            : () => _selectConversation(item),
      ),
    );
  }

  Widget _promptPanel(BuildContext context) {
    final selected = _selected!;
    final schedulingReviewInventoryResourceError =
        _inventoryResourceObservationErrorFor('Scheduling review');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Prompt history'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(selected.conversation.title),
            if (_promptError != null)
              _inlineError(context, _promptError!, _signIn),
            if (_loadingPrompts && _prompts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_hasMorePrompts)
              TextButton(
                onPressed: _loadingPrompts
                    ? null
                    : () => _loadPrompts(
                        selected.conversation.id,
                        loadOlder: true,
                      ),
                child: Text(context.tr('Load older prompts')),
              ),
            for (final prompt in _prompts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr(prompt.role)),
                subtitle: SelectableText(prompt.content),
                dense: true,
              ),
            TextField(
              controller: _promptController,
              enabled: !_appending && _pendingPrompt == null,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.tr('Prompt'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_appendError != null)
              _inlineError(context, _appendError!, _signIn),
            if (_promptAppendInventoryResourceConvergenceError != null)
              _inlineError(
                context,
                _promptAppendInventoryResourceConvergenceError!,
                _signIn,
              ),
            if (_pendingRunIntentSubmitError != null)
              _inlineError(context, _pendingRunIntentSubmitError!, _signIn),
            if (schedulingReviewInventoryResourceError != null)
              _inlineError(
                context,
                schedulingReviewInventoryResourceError,
                _signIn,
              ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _appending ||
                          _submittingPendingRunIntent ||
                          _promptAppendInventoryResourceConvergenceError != null
                      ? null
                      : _appendPrompt,
                  icon: _appending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _pendingPrompt == null
                        ? context.tr('Append prompt')
                        : context.tr('Retry prompt'),
                  ),
                ),
                if (widget.pendingRunIntentSubmitter != null &&
                    widget.pendingRunIntentOwner != null)
                  OutlinedButton.icon(
                    key: const ValueKey('forge-request-scheduling-review'),
                    onPressed:
                        _appending ||
                            _submittingPendingRunIntent ||
                            schedulingReviewInventoryResourceError != null
                        ? null
                        : _submitPendingRunIntent,
                    icon: _submittingPendingRunIntent
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add_check),
                    label: LocalizedText(
                      _pendingRunIntentRequest == null
                          ? 'Request scheduling review'
                          : 'Retry scheduling review',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
