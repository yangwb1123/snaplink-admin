part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenPendingIntentTimeline
    on _ForgeSessionsScreenState {
  Future<void> _loadPendingRunIntentTimeline(String intentID) async {
    final reader = widget.pendingRunIntentTimelineReader;
    final conversationID = _selected?.conversation.id;
    final page = _fetchedPendingRunIntents;
    if (!mounted ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        reader == null ||
        conversationID == null ||
        page == null) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final intent = page.intents.where((entry) => entry.intentID == intentID);
    if (intent.length != 1 ||
        _fetchedPendingRunIntentTimelines.containsKey(intentID) ||
        _loadingPendingRunIntentTimelines.contains(intentID)) {
      return;
    }
    final generation = _pendingRunIntentTimelineGeneration;
    void revokeIfHidden() {
      if (mounted &&
          _selected?.conversation.id == conversationID &&
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        _update(_clearRunDetailsForHiddenClientInstance);
      }
    }

    _update(() {
      _loadingPendingRunIntentTimelines.add(intentID);
      _pendingRunIntentTimelineErrors.remove(intentID);
    });
    try {
      // Re-decode through the strict timeline boundary. This preserves the
      // Conversation/intent binding, initial sequence, event type, and
      // payload-free closed shape even when a test adapter constructs the
      // public value directly.
      final timeline = ForgePendingRunIntentTimelinePage.fromJson(
        _pendingRunIntentTimelineWire(await reader(conversationID, intentID)),
        requestedConversationID: conversationID,
        requestedIntentID: intentID,
        requestedAfterSequence: 0,
      );
      if (timeline.events.single.emittedAtMS != intent.single.submittedAtMS) {
        throw const FormatException(
          'Forge returned an unbound pending Run-intent timeline.',
        );
      }
      if (!mounted ||
          generation != _pendingRunIntentTimelineGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      _update(() {
        _fetchedPendingRunIntentTimelines[intentID] = timeline;
        _pendingRunIntentTimelineErrors.remove(intentID);
        _loadingPendingRunIntentTimelines.remove(intentID);
      });
    } catch (error) {
      if (!mounted || generation != _pendingRunIntentTimelineGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _pendingRunIntentTimelineGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        revokeIfHidden();
        return;
      }
      _update(() {
        _fetchedPendingRunIntentTimelines.remove(intentID);
        _pendingRunIntentTimelineErrors[intentID] = _friendlyError(
          error,
          'Could not load pending Run-intent timeline.',
        );
        _loadingPendingRunIntentTimelines.remove(intentID);
      });
    }
  }

  Map<String, dynamic> _pendingRunIntentTimelineWire(
    ForgePendingRunIntentTimelinePage page,
  ) => {
    'conversation_id': page.conversationID,
    'intent_id': page.intentID,
    'after_sequence': page.afterSequence,
    'scanned_through_sequence': page.scannedThroughSequence,
    'has_more': page.hasMore,
    'events': page.events
        .map(
          (event) => {
            'event_id': event.eventID,
            'seq': event.sequence,
            'emitted_at_ms': event.emittedAtMS,
            'type': event.type,
          },
        )
        .toList(growable: false),
  };

  void _clearPendingRunIntentTimelines() {
    _pendingRunIntentTimelineGeneration++;
    _fetchedPendingRunIntentTimelines.clear();
    _pendingRunIntentTimelineErrors.clear();
    _loadingPendingRunIntentTimelines.clear();
  }
}
