part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenClientInstanceFilter
    on _ForgeSessionsScreenState {
  /// Revokes owner Prompt/Run state as soon as a refreshed local
  /// client-instance projection no longer declares the selected conversation.
  /// The selection itself remains a bookmark, but a later projection refresh
  /// must not resurrect the old private metadata without a new owner read.
  void _reconcileSelectedClientInstanceProjection() {
    final conversationID = _selected?.conversation.id;
    if (_selectedClientInstanceID == null || conversationID == null) return;
    if (_conversationVisibleFromSelectedClientInstance(conversationID)) return;
    if (mounted) _update(_clearRunDetailsForHiddenClientInstance);
  }

  /// Returns the owner-scoped conversations visible from one caller-declared
  /// client instance. The instance declaration is an observation only; an
  /// unknown instance or session simply produces an empty local projection.
  /// No server request or authority decision is made here.
  List<ForgeOwnedConversation> conversationsForClientInstance(
    Iterable<ForgeClientInstanceSessionViewInstance>? instances,
    String? instanceID,
  ) => _conversationsForClientInstance(_conversations, instances, instanceID);

  List<ForgeOwnedConversation> _conversationsForClientInstance(
    Iterable<ForgeOwnedConversation> source,
    Iterable<ForgeClientInstanceSessionViewInstance>? instances,
    String? instanceID,
  ) {
    if (instanceID == null) return source.toList(growable: false);
    if (instances == null) return const [];
    ForgeClientInstanceSessionViewInstance? instance;
    for (final candidate in instances) {
      if (candidate.instanceID == instanceID) {
        instance = candidate;
        break;
      }
    }
    if (instance == null) return const [];
    final sessionIDs = instance.sessionIDs.toSet();
    return source
        .where((entry) => sessionIDs.contains(entry.conversation.id))
        .toList(growable: false);
  }

  Iterable<ForgeClientInstanceSessionViewInstance>?
  _declaredClientInstanceRows() {
    final sessionView =
        _strictClientInstanceSessionView(
          widget.clientInstanceSessionViewPreview,
        ) ??
        _strictClientInstanceSessionView(_fetchedClientInstanceSessionView) ??
        _strictClientInstanceSessionView(_clientInstanceSessionViewPreview);
    final resourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        _fetchedClientInstanceSessionResourceConvergence?.resourceView ??
        _fetchedDeviceInventoryResourceConvergence?.resourceView;

    // When the caller opted into two independent readers, neither response
    // can define the local filter by itself. During a reader gap or a
    // mismatched refresh, return no declaration so a selected instance cannot
    // broaden back to the owner-wide session list or hydrate private state
    // from a mixed snapshot. The combined reader already performs this join
    // before populating both fetched views.
    if (_independentClientInstanceReadersConfigured) {
      if (sessionView == null ||
          resourceView == null ||
          _loadingClientInstanceSessionView ||
          _loadingClientInstanceResourceView ||
          _clientInstanceSessionViewError != null ||
          _clientInstanceResourceViewError != null ||
          _clientInstanceSessionViewStale ||
          _clientInstanceResourceViewStale ||
          !forgeClientInstanceSessionResourceObservationsConverged(
            sessionView,
            resourceView,
          )) {
        return null;
      }
    }
    return sessionView?.instances ?? resourceView?.instances;
  }

  bool get _independentClientInstanceReadersConfigured =>
      widget.clientInstanceSessionViewOwner != null &&
      widget.clientInstanceSessionViewReader != null &&
      widget.clientInstanceResourceViewOwner != null &&
      widget.clientInstanceResourceViewReader != null;

  bool _conversationIDDeclaredBySelectedClientInstance(String? conversationID) {
    if (conversationID == null || _selectedClientInstanceID == null) {
      return true;
    }
    final rows = _declaredClientInstanceRows();
    if (rows == null) return false;
    for (final row in rows) {
      if (row.instanceID == _selectedClientInstanceID &&
          row.sessionIDs.contains(conversationID)) {
        return true;
      }
    }
    return false;
  }

  /// Selects a local client-instance session filter. Any change invalidates
  /// the private Prompt/Run projection, including when a shared Conversation
  /// remains visible from both instances; if the current session is outside
  /// the selected instance, select the first visible owner session so the
  /// Prompt panel cannot continue showing a hidden row.
  void selectClientInstanceFilter(
    Iterable<ForgeClientInstanceSessionViewInstance>? instances,
    String? instanceID,
  ) {
    final visible = conversationsForClientInstance(instances, instanceID);
    final currentID = _selected?.conversation.id;
    final currentVisible = visible.any(
      (entry) => entry.conversation.id == currentID,
    );
    final filterChanged = _selectedClientInstanceID != instanceID;
    _clientInstanceFilterGeneration++;
    _update(() {
      _selectedClientInstanceID = instanceID;
      if (!currentVisible) {
        _selected = null;
        _clearConversationDetails(clearOwnerObservations: false);
      } else if (filterChanged) {
        // A shared Conversation can be declared by more than one client
        // instance. Changing the local projection still requires a fresh
        // private read, even when the selected row remains visible. Keep the
        // owner-scoped observation panels mounted; only Prompt/Run state is
        // invalidated at this display boundary.
        _clearRunDetailsForHiddenClientInstance();
      }
    });
    if (visible.isNotEmpty && !currentVisible) {
      unawaited(_selectConversation(visible.first));
    }
  }

  bool _conversationVisibleFromSelectedClientInstance(String conversationID) {
    final instanceID = _selectedClientInstanceID;
    if (instanceID == null) return true;
    final instances = _declaredClientInstanceRows();
    return instances != null &&
        conversationsForClientInstance(
          instances,
          instanceID,
        ).any((entry) => entry.conversation.id == conversationID);
  }

  List<ForgeConversationChange> _conversationChangesVisibleFromSelectedInstance(
    Iterable<ForgeConversationChange> changes,
  ) {
    if (_selectedClientInstanceID == null) {
      return changes.toList(growable: false);
    }
    return changes
        .where(
          (change) => _conversationIDDeclaredBySelectedClientInstance(
            change.conversationID,
          ),
        )
        .toList(growable: false);
  }

  Future<bool>
  _refreshSelectedClientInstanceProjectionBeforeOwnerReads() async {
    if (_selectedClientInstanceID == null) return true;
    await _loadClientInstanceSessionResourceConvergenceIfRequested(force: true);
    await _loadClientInstanceSessionViewIfRequested(force: true);
    await _loadClientInstanceResourceViewIfRequested(force: true);
    return _selectedClientInstanceProjectionReadyForOwnerReads();
  }

  bool _selectedClientInstanceProjectionReadyForOwnerReads() {
    if (_selectedClientInstanceID == null) return true;

    final pairConfigured =
        widget.clientInstanceSessionResourceConvergenceOwner != null &&
        widget.clientInstanceSessionResourceConvergenceReader != null;
    if (pairConfigured &&
        (_fetchedClientInstanceSessionResourceConvergence == null ||
            _loadingClientInstanceSessionResourceConvergence ||
            _clientInstanceSessionResourceConvergenceError != null ||
            _clientInstanceSessionResourceConvergenceStale)) {
      return false;
    }

    final sessionConfigured =
        widget.clientInstanceSessionViewOwner != null &&
        widget.clientInstanceSessionViewReader != null;
    if (sessionConfigured &&
        (_fetchedClientInstanceSessionView == null ||
            _loadingClientInstanceSessionView ||
            _clientInstanceSessionViewError != null ||
            _clientInstanceSessionViewStale)) {
      return false;
    }

    final resourceConfigured =
        widget.clientInstanceResourceViewOwner != null &&
        widget.clientInstanceResourceViewReader != null;
    if (resourceConfigured &&
        (_fetchedClientInstanceResourceView == null ||
            _loadingClientInstanceResourceView ||
            _clientInstanceResourceViewError != null ||
            _clientInstanceResourceViewStale)) {
      return false;
    }

    if (_independentClientInstanceReadersConfigured) {
      final sessionView = _fetchedClientInstanceSessionView;
      final resourceView = _fetchedClientInstanceResourceView;
      if (sessionView == null ||
          resourceView == null ||
          !forgeClientInstanceSessionResourceObservationsConverged(
            sessionView,
            resourceView,
          )) {
        return false;
      }
    }

    // A selected instance still needs a validated local declaration when the
    // caller supplied only a process-local preview. Unknown or missing rows
    // fail closed and cannot widen the owner session surface. The latest
    // observation must still contain the selected instance; an empty row set
    // is a revocation and cannot authorize another owner-feed read.
    final rows = _declaredClientInstanceRows();
    if (rows == null) return false;
    return rows.any((row) => row.instanceID == _selectedClientInstanceID);
  }
}
