part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenPromptAppend on _ForgeSessionsScreenState {
  Future<void> _appendPrompt() async {
    final selected = _selected;
    if (selected == null || _appending) return;
    if (!_conversationVisibleFromSelectedClientInstance(
      selected.conversation.id,
    )) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    // The local instance filter is only a display projection. Refresh it at
    // the write boundary so a revoked session cannot keep a Prompt POST alive
    // after the selected instance changed. The default surface remains
    // request-free because this helper is a no-op without an injected reader.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _appendError =
              'Prompt append is waiting for a fresh validated client-instance session/resource observation.';
        });
      }
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Prompt append',
          force: true,
        );
    if (!mounted || _selected?.conversation.id != selected.conversation.id) {
      return;
    }
    if (observationError != null) {
      _update(() => _appendError = observationError);
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
    final convergenceError = _promptAppendInventoryResourceConvergenceError;
    if (convergenceError != null) {
      _update(() {
        _appendError = convergenceError;
      });
      return;
    }
    final pending = _pendingPrompt ?? _readPromptRequest(selected);
    if (pending == null) return;
    _update(() {
      _pendingPrompt = pending;
      _appending = true;
      _appendError = null;
    });
    try {
      final receiptOwner = widget.promptAppendReceiptOwner;
      final receiptSubmitter = widget.promptAppendReceiptSubmitter;
      final receiptOptIn = receiptOwner != null || receiptSubmitter != null;
      if (receiptOptIn && (receiptOwner == null || receiptSubmitter == null)) {
        throw const FormatException(
          'Prompt append receipt consumer is not fully configured.',
        );
      }
      ForgePromptAppendReceiptObservation? receipt;
      ForgePromptAppendResult? result;
      if (receiptOptIn) {
        final owner = ForgeDeviceOwner.fromJson(receiptOwner!.toJson());
        receipt = ForgePromptAppendReceiptObservation.fromJson(
          (await receiptSubmitter!(
            owner: owner,
            conversationID: selected.conversation.id,
            content: pending.content,
            expectedVersion: pending.expectedVersion,
            idempotencyKey: pending.idempotencyKey,
          )).toJson(),
        );
        final expectedReceipt = ForgePromptAppendReceiptObservation.fromInput(
          owner: owner,
          conversationID: selected.conversation.id,
          expectedVersion: pending.expectedVersion,
          content: pending.content,
          idempotencyKey: pending.idempotencyKey,
          promptID: receipt.receipt.promptID,
          createdAtMS: receipt.receipt.createdAtMS,
          replayed: receipt.receipt.replayed,
        );
        if (jsonEncode(receipt.toJson()) !=
            jsonEncode(expectedReceipt.toJson())) {
          throw const FormatException(
            'Forge returned a Prompt append receipt with invalid binding.',
          );
        }
      } else {
        result = await _api.appendPrompt(
          conversationID: selected.conversation.id,
          content: pending.content,
          expectedVersion: pending.expectedVersion,
          idempotencyKey: pending.idempotencyKey,
        );
      }
      if (!mounted ||
          _selected?.conversation.id != selected.conversation.id ||
          !_conversationVisibleFromSelectedClientInstance(
            selected.conversation.id,
          )) {
        return;
      }
      if (receipt != null) {
        final updated = ForgeOwnedConversation(
          conversation: selected.conversation,
          aggregateVersion: receipt.receipt.aggregateVersion,
        );
        _update(() {
          _selected = updated;
          _conversations = _replaceConversation(_conversations, updated);
          _pendingPrompt = null;
          _promptController.clear();
          _appending = false;
        });
        // The receipt intentionally carries no Prompt body. Refresh the
        // already-authorized history after the write so the display obtains
        // the persisted row through the ordinary owner-scoped read.
        await _loadPrompts(selected.conversation.id);
        if (!mounted ||
            _selected?.conversation.id != selected.conversation.id ||
            !_conversationVisibleFromSelectedClientInstance(
              selected.conversation.id,
            )) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              receipt.receipt.replayed
                  ? context.tr(
                      'Prompt retry replayed the existing message. It has not started a task.',
                    )
                  : context.tr('Prompt stored. It has not started a task.'),
            ),
          ),
        );
        return;
      }
      final appended = result!;
      final updated = ForgeOwnedConversation(
        conversation: selected.conversation,
        aggregateVersion: appended.aggregateVersion,
      );
      _update(() {
        _selected = updated;
        _conversations = _replaceConversation(_conversations, updated);
        _prompts = _uniquePrompts(
          [..._prompts, appended.prompt]..sort(_comparePrompts),
        );
        _pendingPrompt = null;
        _promptController.clear();
        _appending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appended.replayed
                ? context.tr(
                    'Prompt retry replayed the existing message. It has not started a task.',
                  )
                : context.tr('Prompt stored. It has not started a task.'),
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
        if (terminal) _pendingPrompt = null;
        _appendError = _friendlyError(
          error,
          'Forge did not confirm the prompt write.',
        );
        _appending = false;
      });
      if (status == 409) {
        await _refreshConversations(selectID: selected.conversation.id);
      }
    }
  }

  _PendingPrompt? _readPromptRequest(ForgeOwnedConversation selected) {
    // Preserve the exact bytes entered by the user so Flutter has the same
    // Prompt semantics as the CLI, TUI, and API clients. Trimming is only a
    // validation check for an all-whitespace value.
    final content = _promptController.text;
    if (content.trim().isEmpty) {
      _update(() => _appendError = 'Enter a prompt to send.');
      return null;
    }
    return _PendingPrompt(
      content: content,
      expectedVersion: selected.aggregateVersion,
      idempotencyKey: newForgeIdempotencyKey(),
    );
  }

  bool _isDefinitiveWriteFailure(Object error) {
    if (error is! ForgeConversationsApiException) return false;
    if (error.statusCode == 409) return true;
    if (error.statusCode == 408 ||
        error.statusCode == 425 ||
        error.statusCode == 429) {
      return false;
    }
    return error.statusCode >= 400 && error.statusCode < 500;
  }
}
