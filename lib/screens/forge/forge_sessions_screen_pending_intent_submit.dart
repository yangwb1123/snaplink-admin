part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenPendingIntentSubmit on _ForgeSessionsScreenState {
  Future<void> _submitPendingRunIntent() async {
    final selected = _selected;
    final owner = widget.pendingRunIntentOwner;
    final submitter = widget.pendingRunIntentSubmitter;
    if (selected == null || owner == null || submitter == null) return;
    if (!_conversationVisibleFromSelectedClientInstance(
      selected.conversation.id,
    )) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _pendingRunIntentSubmitError =
              'Scheduling review is waiting for a fresh validated client-instance session/resource observation.';
        });
      }
      return;
    }
    if (!mounted || _selected?.conversation.id != selected.conversation.id) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(
      selected.conversation.id,
    )) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Scheduling review',
        );
    if (!mounted || _selected?.conversation.id != selected.conversation.id) {
      return;
    }
    if (observationError != null) {
      _update(() => _pendingRunIntentSubmitError = observationError);
      return;
    }
    final pending =
        _pendingRunIntentRequest ?? _readPendingRunIntentRequest(selected);
    if (pending == null) return;
    _update(() {
      _pendingRunIntentRequest = pending;
      _submittingPendingRunIntent = true;
      _pendingRunIntentSubmitError = null;
    });
    try {
      final result = await submitter(
        owner: owner,
        conversationID: selected.conversation.id,
        content: pending.content,
        expectedVersion: pending.expectedVersion,
        idempotencyKey: pending.idempotencyKey,
      );
      if (result.prompt.conversationID != selected.conversation.id ||
          result.prompt.role != 'user' ||
          result.prompt.content != pending.content ||
          result.intent.conversationID != selected.conversation.id ||
          result.intent.promptID != result.prompt.id ||
          result.initialEvent.sequence != 1 ||
          result.initialEvent.type != 'submitted' ||
          result.intent.status != 'pending') {
        throw const FormatException(
          'Forge returned an invalid scheduling-review receipt.',
        );
      }
      if (!mounted ||
          _selected?.conversation.id != selected.conversation.id ||
          !_conversationVisibleFromSelectedClientInstance(
            selected.conversation.id,
          )) {
        return;
      }
      final updated = ForgeOwnedConversation(
        conversation: selected.conversation,
        aggregateVersion: result.intent.aggregateVersion,
      );
      _update(() {
        _selected = updated;
        _conversations = _replaceConversation(_conversations, updated);
        _prompts = _uniquePrompts(
          [
            ..._prompts,
            ForgeConversationPrompt(
              id: result.prompt.id,
              conversationID: result.prompt.conversationID,
              role: result.prompt.role,
              content: result.prompt.content,
              createdAtMS: result.prompt.createdAtMS,
            ),
          ].toList()..sort(_comparePrompts),
        );
        _pendingRunIntentSubmission = result;
        _pendingRunIntentRequest = null;
        _promptController.clear();
        _submittingPendingRunIntent = false;
      });
      // A successful scheduling-review write advances the Conversation
      // aggregate and creates one inert receipt. If the caller explicitly
      // supplied the metadata reader, refresh it now so the shared Gate shows
      // the server-owned receipt without requiring a second manual sync.
      await _loadPendingRunIntentsIfRequested(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Scheduling review requested. No task has started.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          !_conversationVisibleFromSelectedClientInstance(
            selected.conversation.id,
          )) {
        return;
      }
      final status = error is ForgeConversationsApiException
          ? error.statusCode
          : 0;
      final terminal = _isDefinitiveWriteFailure(error);
      _update(() {
        if (terminal) _pendingRunIntentRequest = null;
        _pendingRunIntentSubmitError = _friendlyError(
          error,
          'Forge did not confirm the scheduling-review request.',
        );
        _submittingPendingRunIntent = false;
      });
      if (status == 409) {
        await _refreshConversations(selectID: selected.conversation.id);
      }
    }
  }

  _PendingRunIntentRequest? _readPendingRunIntentRequest(
    ForgeOwnedConversation selected,
  ) {
    final content = _promptController.text;
    if (content.trim().isEmpty) {
      _update(() => _pendingRunIntentSubmitError = 'Enter a prompt to review.');
      return null;
    }
    return _PendingRunIntentRequest(
      content: content,
      expectedVersion: selected.aggregateVersion,
      idempotencyKey: newForgeIdempotencyKey(),
    );
  }
}
