part of 'forge_sessions_screen.dart';

class _ForgeSessionsView extends StatelessWidget {
  final _ForgeSessionsScreenState state;

  const _ForgeSessionsView({required this.state});

  @override
  Widget build(BuildContext context) => state.render(context);
}

extension on _ForgeSessionsScreenState {
  Widget render(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Forge Sessions')),
        actions: [
          IconButton(
            tooltip: context.tr('Sign out of Forge on this device'),
            onPressed: _signOutThisDevice,
            icon: const Icon(Icons.logout_outlined),
          ),
          IconButton(
            tooltip: strings.refresh,
            onPressed: _refreshAndSync,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAndSync,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _createCard(context),
            if (_conversationError != null)
              _errorCard(context, _conversationError!, _signIn),
            if (_changeError != null)
              _errorCard(context, _changeError!, _signIn),
            if (_loadingConversations && _conversations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!_loadingConversations &&
                _conversationError == null &&
                _conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.tr('No Forge conversations yet.')),
              ),
            for (final item in _conversations) _conversationTile(context, item),
            if (_hasMoreConversations)
              Center(
                child: TextButton(
                  onPressed: _loadingConversations
                      ? null
                      : () => _refreshConversations(loadMore: true),
                  child: Text(context.tr('Load more conversations')),
                ),
              ),
            if (_selected != null) _promptPanel(context),
            if (_selected != null) _runPanel(context),
          ],
        ),
      ),
    );
  }

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
            onPressed: _creating || _appending || _pendingPrompt != null
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
        selected: selected,
        title: Text(
          item.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(item.conversation.scope.label),
        trailing: selected ? const Icon(Icons.chevron_right) : null,
        onTap: _appending || _pendingPrompt != null
            ? null
            : () => _selectConversation(item),
      ),
    );
  }

  Widget _promptPanel(BuildContext context) {
    final selected = _selected!;
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _appending ? null : _appendPrompt,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(
    BuildContext context,
    String message,
    VoidCallback onSignIn,
  ) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: Text(context.tr(message))),
          if (message == _forgeAuthRequiredMessage)
            TextButton(onPressed: onSignIn, child: Text(context.tr('Sign in'))),
        ],
      ),
    ),
  );

  Widget _inlineError(
    BuildContext context,
    String message,
    VoidCallback onSignIn,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.tr(message),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        if (message == _forgeAuthRequiredMessage)
          TextButton(onPressed: onSignIn, child: Text(context.tr('Sign in'))),
      ],
    ),
  );
}
