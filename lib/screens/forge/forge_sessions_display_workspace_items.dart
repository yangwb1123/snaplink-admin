part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayWorkspaceItems on _ForgeSessionsScreenState {
  List<Widget> _conversationsItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final visibleConversations = display.selection.visibleConversations;
    return <Widget>[
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
      if (!_loadingConversations &&
          _conversationError == null &&
          _conversations.isNotEmpty &&
          visibleConversations.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.tr(
              'No conversations are visible from this client instance.',
            ),
          ),
        ),
      for (final item in visibleConversations) _conversationTile(context, item),
      if (_hasMoreConversations)
        Center(
          child: TextButton(
            onPressed: _loadingConversations
                ? null
                : () => _refreshConversations(loadMore: true),
            child: Text(context.tr('Load more conversations')),
          ),
        ),
    ];
  }

  List<Widget> _pendingWorkspaceItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final selectedConversationVisible =
        display.selection.selectedConversationVisible;
    final pendingRunIntentReader = display.receipts.pendingRunIntentReader;
    final pendingRunIntentPageReader =
        display.receipts.pendingRunIntentPageReader;
    return <Widget>[
      if (selectedConversationVisible &&
          (pendingRunIntentReader != null ||
              pendingRunIntentPageReader != null) &&
          _pendingRunIntentError != null)
        _errorCard(context, _pendingRunIntentError!, _signIn),
      if (selectedConversationVisible &&
          (pendingRunIntentReader != null ||
              pendingRunIntentPageReader != null) &&
          (_loadingPendingRunIntents || _loadingMorePendingRunIntents))
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (selectedConversationVisible &&
          (pendingRunIntentReader != null ||
              pendingRunIntentPageReader != null) &&
          _fetchedPendingRunIntents != null)
        ForgePendingRunIntentMetadataPanel(
          page: _fetchedPendingRunIntents!,
          timelines: _fetchedPendingRunIntentTimelines,
          loadingTimelineIntentIDs: _loadingPendingRunIntentTimelines,
          timelineErrors: _pendingRunIntentTimelineErrors,
          onTimelineExpanded: widget.pendingRunIntentTimelineReader == null
              ? null
              : (intentID) =>
                    unawaited(_loadPendingRunIntentTimeline(intentID)),
          onLoadMore: pendingRunIntentPageReader == null
              ? null
              : () => unawaited(_loadMorePendingRunIntents()),
          loadingMore: _loadingMorePendingRunIntents,
        ),
      if (_selected != null && selectedConversationVisible)
        _promptPanel(context),
      if (_selected != null &&
          selectedConversationVisible &&
          _pendingRunIntentSubmission != null &&
          widget.pendingRunIntentOwner != null)
        ForgePendingRunIntentSubmissionCard(
          submission: _pendingRunIntentSubmission!,
          owner: widget.pendingRunIntentOwner!,
        ),
      if (_selected != null && selectedConversationVisible) _runPanel(context),
    ];
  }
}
