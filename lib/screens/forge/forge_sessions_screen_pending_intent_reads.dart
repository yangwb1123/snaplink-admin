part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenPendingIntentReads on _ForgeSessionsScreenState {
  Future<void> _loadPendingRunIntentsIfRequested({bool force = false}) async {
    final reader = widget.pendingRunIntentReader;
    final pageReader = widget.pendingRunIntentPageReader;
    final conversationID = _selected?.conversation.id;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (conversationID != null &&
        !_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if ((reader == null && pageReader == null) || conversationID == null) {
      if (mounted &&
          (_fetchedPendingRunIntents != null ||
              _pendingRunIntentError != null ||
              _loadingPendingRunIntents)) {
        _update(_clearPendingRunIntents);
      }
      return;
    }
    if (_loadingPendingRunIntents || _loadingMorePendingRunIntents) return;
    if (!force &&
        (_fetchedPendingRunIntents != null || _pendingRunIntentError != null)) {
      return;
    }
    final previousPage = _fetchedPendingRunIntents;
    final preserveTimelines = previousPage != null;
    final generation = ++_pendingRunIntentGeneration;
    void revokeIfHidden() {
      if (mounted &&
          _selected?.conversation.id == conversationID &&
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        _update(_clearRunDetailsForHiddenClientInstance);
      }
    }

    _update(() {
      _loadingPendingRunIntents = true;
      _pendingRunIntentError = null;
      _fetchedPendingRunIntents = null;
    });
    try {
      // Re-decode the callback result through the strict list boundary. This
      // preserves conversation binding, cursor ordering, pending status, and
      // the bounded initial sequence even when a test adapter constructs the
      // public value directly.
      final response = pageReader != null
          ? await pageReader(conversationID, null)
          : await reader!(conversationID);
      final page = ForgePendingRunIntentListPage.fromJson(
        _pendingRunIntentPageWire(response),
        requestedConversationID: conversationID,
      );
      if (!mounted ||
          generation != _pendingRunIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      final samePage =
          preserveTimelines && _samePendingRunIntentPage(previousPage, page);
      _update(() {
        if (!samePage) _clearPendingRunIntentTimelines();
        _fetchedPendingRunIntents = page;
        _pendingRunIntentError = null;
        _loadingPendingRunIntents = false;
      });
    } catch (error) {
      if (!mounted || generation != _pendingRunIntentGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _pendingRunIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      _update(() {
        _clearPendingRunIntentTimelines();
        _fetchedPendingRunIntents = null;
        _pendingRunIntentError = _friendlyError(
          error,
          'Could not load pending Run-intent metadata.',
        );
        _loadingPendingRunIntents = false;
      });
    }
  }

  Future<void> _loadMorePendingRunIntents() async {
    final reader = widget.pendingRunIntentPageReader;
    final conversationID = _selected?.conversation.id;
    final current = _fetchedPendingRunIntents;
    final cursor = current?.nextCursor;
    if (!mounted ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        reader == null ||
        conversationID == null ||
        current == null ||
        !current.hasMore ||
        cursor == null ||
        _loadingPendingRunIntents ||
        _loadingMorePendingRunIntents) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final generation = _pendingRunIntentGeneration;
    void revokeIfHidden() {
      if (mounted &&
          _selected?.conversation.id == conversationID &&
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        _update(_clearRunDetailsForHiddenClientInstance);
      }
    }

    _update(() {
      _loadingMorePendingRunIntents = true;
      _pendingRunIntentError = null;
    });
    try {
      final response = await reader(conversationID, cursor);
      final page = ForgePendingRunIntentListPage.fromJson(
        _pendingRunIntentPageWire(response),
        requestedConversationID: conversationID,
        before: cursor,
      );
      if (!mounted ||
          generation != _pendingRunIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          !identical(current, _fetchedPendingRunIntents) ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      final seen = current.intents.map((intent) => intent.intentID).toSet();
      if (page.intents.any((intent) => !seen.add(intent.intentID))) {
        throw const FormatException(
          'Forge returned a duplicate pending Run-intent page.',
        );
      }
      if (page.intents.isNotEmpty) {
        final previous = current.intents.last;
        final first = page.intents.first;
        final firstID = utf8.encode(first.intentID);
        final previousID = utf8.encode(previous.intentID);
        var idComparison = 0;
        final sharedLength = firstID.length < previousID.length
            ? firstID.length
            : previousID.length;
        for (var index = 0; index < sharedLength; index++) {
          idComparison = firstID[index].compareTo(previousID[index]);
          if (idComparison != 0) break;
        }
        if (idComparison == 0) {
          idComparison = firstID.length.compareTo(previousID.length);
        }
        final older =
            first.submittedAtMS < previous.submittedAtMS ||
            (first.submittedAtMS == previous.submittedAtMS && idComparison < 0);
        if (!older) {
          throw const FormatException(
            'Forge returned an out-of-order pending Run-intent page.',
          );
        }
      }
      final merged = <ForgePendingRunIntentRecord>[
        ...current.intents,
        ...page.intents,
      ];
      _update(() {
        _fetchedPendingRunIntents = ForgePendingRunIntentListPage(
          conversationID: conversationID,
          intents: List.unmodifiable(merged),
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        );
        _pendingRunIntentError = null;
        _loadingMorePendingRunIntents = false;
      });
    } catch (error) {
      if (!mounted || generation != _pendingRunIntentGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _pendingRunIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      _update(() {
        _pendingRunIntentError = _friendlyError(
          error,
          'Could not load more pending Run-intent metadata.',
        );
        _loadingMorePendingRunIntents = false;
      });
    }
  }

  Map<String, dynamic> _pendingRunIntentPageWire(
    ForgePendingRunIntentListPage page,
  ) => {
    'conversation_id': page.conversationID,
    'intents': page.intents
        .map(
          (intent) => {
            'intent_id': intent.intentID,
            'conversation_id': intent.conversationID,
            'prompt_id': intent.promptID,
            'project_id': intent.projectID,
            'profile_id': intent.profileID,
            'submitted_at_ms': intent.submittedAtMS,
            'aggregate_version': intent.aggregateVersion,
            'latest_sequence': intent.latestSequence,
            'status': intent.status,
          },
        )
        .toList(growable: false),
    'has_more': page.hasMore,
    if (page.nextCursor != null) 'next_cursor': page.nextCursor!.toJson(),
  };

  bool _samePendingRunIntentPage(
    ForgePendingRunIntentListPage? left,
    ForgePendingRunIntentListPage right,
  ) {
    if (left == null ||
        left.conversationID != right.conversationID ||
        left.hasMore != right.hasMore ||
        left.nextCursor?.submittedAtMS != right.nextCursor?.submittedAtMS ||
        left.nextCursor?.intentID != right.nextCursor?.intentID ||
        left.intents.length != right.intents.length) {
      return false;
    }
    for (var index = 0; index < left.intents.length; index++) {
      if (!left.intents[index].sameValue(right.intents[index])) return false;
    }
    return true;
  }

  void _clearPendingRunIntents() {
    _pendingRunIntentGeneration++;
    _fetchedPendingRunIntents = null;
    _pendingRunIntentError = null;
    _loadingPendingRunIntents = false;
    _loadingMorePendingRunIntents = false;
    _clearPendingRunIntentTimelines();
  }
}
