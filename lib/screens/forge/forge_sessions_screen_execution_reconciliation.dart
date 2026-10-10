part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenExecutionReconciliation
    on _ForgeSessionsScreenState {
  Future<void> _loadExecutionReconciliationIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final input = widget.executionReconciliationInput;
    final reader = widget.executionReconciliationReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (input == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        !input.isFor(conversationID, runID)) {
      if (mounted &&
          (_fetchedExecutionReconciliationObservation != null ||
              _executionReconciliationError != null ||
              _loadingExecutionReconciliation ||
              _executionReconciliationStale)) {
        _update(_clearExecutionReconciliation);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingExecutionReconciliation) return;
    if (!force &&
        (_fetchedExecutionReconciliationObservation != null ||
            _executionReconciliationError != null)) {
      return;
    }
    final previous = _fetchedExecutionReconciliationObservation;
    final generation = ++_executionReconciliationGeneration;
    _update(() {
      _loadingExecutionReconciliation = true;
      _executionReconciliationError = null;
      _executionReconciliationStale = previous != null;
    });
    try {
      final validatedInput = ForgeExecutionReconciliationInput.fromJson(
        input.toJson(),
      );
      if (!validatedInput.isFor(conversationID, runID)) {
        throw const FormatException(
          'Forge execution reconciliation input is bound to another Run.',
        );
      }
      final observation = ForgeExecutionReconciliationObservation.fromJson(
        (await reader(validatedInput)).toJson(),
      );
      final expected = observeForgeExecutionReconciliation(validatedInput);
      if (!observation.isFor(conversationID, runID) ||
          observation.owner != validatedInput.owner ||
          jsonEncode(observation.toJson()) != jsonEncode(expected.toJson())) {
        throw const FormatException(
          'Forge returned an invalid or differently bound execution reconciliation observation.',
        );
      }
      if (!mounted ||
          generation != _executionReconciliationGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedExecutionReconciliationObservation = observation;
        _executionReconciliationError = null;
        _executionReconciliationStale = false;
        _loadingExecutionReconciliation = false;
      });
    } catch (error) {
      if (!mounted || generation != _executionReconciliationGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _executionReconciliationGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedExecutionReconciliationObservation = previous;
        _executionReconciliationError = _friendlyError(
          error,
          'Could not load execution reconciliation observation.',
        );
        _executionReconciliationStale = previous != null;
        _loadingExecutionReconciliation = false;
      });
    }
  }

  void _clearExecutionReconciliation() {
    _executionReconciliationGeneration++;
    _fetchedExecutionReconciliationObservation = null;
    _executionReconciliationError = null;
    _executionReconciliationStale = false;
    _loadingExecutionReconciliation = false;
  }

  Future<void> _loadExecutionConsentPreviewIfRequested({
    String? conversationID,
    bool force = false,
  }) async {
    final owner = widget.executionConsentPreviewOwner;
    final reader = widget.executionConsentPreviewReader;
    conversationID ??= _selected?.conversation.id;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null || conversationID == null) {
      if (mounted &&
          (_fetchedExecutionConsentPreview != null ||
              _executionConsentPreviewError != null ||
              _loadingExecutionConsentPreview ||
              _executionConsentPreviewStale)) {
        _update(_clearExecutionConsentPreview);
      }
      return;
    }
    // Execution-consent preview is bound to the selected Conversation. Once
    // a caller selects a client instance, keep the candidate read behind the
    // same local projection used by Prompt, Run, and pending Run-intent
    // reads. The projection is display-only and never grants consent.
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) _update(_clearExecutionConsentPreview);
      return;
    }
    if (_loadingExecutionConsentPreview) return;
    if (!force &&
        (_fetchedExecutionConsentPreview != null ||
            _executionConsentPreviewError != null)) {
      return;
    }
    final previous = _fetchedExecutionConsentPreview;
    final generation = ++_executionConsentPreviewGeneration;
    _update(() {
      _loadingExecutionConsentPreview = true;
      _executionConsentPreviewError = null;
      _executionConsentPreviewStale = previous != null;
    });
    try {
      final validatedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final preview = ForgeExecutionConsentPreview.fromJson(
        (await reader(
          owner: validatedOwner,
          conversationID: conversationID,
        )).toJson(),
      );
      if (preview.conversationID != conversationID) {
        throw const FormatException(
          'Forge returned an execution consent preview for another conversation.',
        );
      }
      if (!mounted ||
          generation != _executionConsentPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedExecutionConsentPreview = preview;
        _executionConsentPreviewError = null;
        _executionConsentPreviewStale = false;
        _loadingExecutionConsentPreview = false;
      });
    } catch (error) {
      if (!mounted || generation != _executionConsentPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _executionConsentPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedExecutionConsentPreview = previous;
        _executionConsentPreviewError = _friendlyError(
          error,
          'Could not load execution consent preview.',
        );
        _executionConsentPreviewStale = previous != null;
        _loadingExecutionConsentPreview = false;
      });
    }
  }

  void _clearExecutionConsentPreview() {
    _executionConsentPreviewGeneration++;
    _fetchedExecutionConsentPreview = null;
    _executionConsentPreviewError = null;
    _executionConsentPreviewStale = false;
    _loadingExecutionConsentPreview = false;
  }
}
