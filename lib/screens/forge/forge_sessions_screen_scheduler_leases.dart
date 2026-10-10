part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenSchedulerLeases on _ForgeSessionsScreenState {
  Future<void> _loadSchedulerSelectionLeaseIfRequested() async {
    final claimRequest = widget.schedulerSelectionLeaseRequest;
    final claimReader = widget.schedulerSelectionLeaseReader;
    final claimIdempotencyKey = widget.schedulerSelectionLeaseIdempotencyKey;
    final renewalRequest = widget.schedulerSelectionLeaseRenewalRequest;
    final renewalReader = widget.schedulerSelectionLeaseRenewalReader;
    final renewalIdempotencyKey =
        widget.schedulerSelectionLeaseRenewalIdempotencyKey;
    // Renewal is a separate explicit candidate. If both candidates are
    // supplied, renewal wins so a caller cannot accidentally claim a second
    // reservation while trying to extend the proof it already holds.
    final isRenewal = renewalRequest != null || renewalReader != null;
    final request = isRenewal ? null : claimRequest;
    final reader = isRenewal ? null : claimReader;
    final idempotencyKey = isRenewal
        ? renewalIdempotencyKey
        : claimIdempotencyKey;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if ((isRenewal && (renewalRequest == null || renewalReader == null)) ||
        (!isRenewal && (request == null || reader == null)) ||
        idempotencyKey == null ||
        idempotencyKey.trim().isEmpty) {
      if (mounted &&
          (_fetchedSchedulerSelectionLease != null ||
              _schedulerSelectionLeaseError != null ||
              _loadingSchedulerSelectionLease)) {
        _update(_clearSchedulerSelectionLease);
      }
      return;
    }
    // Keep an explicit lease candidate scoped to the Conversation and Run
    // currently selected by the Sessions surface. A candidate may be
    // configured before the first owner snapshot (so an empty/default Gate
    // remains compatible), but once a selection exists a different binding
    // is stale and must not reach a claim or renewal route.
    final expectedConversationID = isRenewal
        ? renewalRequest!.conversationID
        : request!.conversationID;
    final expectedRunID = isRenewal ? renewalRequest!.runID : request!.runID;
    if (!_schedulerSelectionRequestVisible(expectedConversationID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionLease != null ||
              _schedulerSelectionLeaseError != null ||
              _loadingSchedulerSelectionLease)) {
        _update(_clearSchedulerSelectionLease);
      }
      return;
    }
    final selectedConversationID = _selected?.conversation.id;
    final selectedRunID = _selectedRun?.runID;
    if ((selectedConversationID != null &&
            selectedConversationID != expectedConversationID) ||
        (selectedRunID != null && selectedRunID != expectedRunID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionLease != null ||
              _schedulerSelectionLeaseError != null ||
              _loadingSchedulerSelectionLease)) {
        _update(_clearSchedulerSelectionLease);
      }
      return;
    }
    if (_loadingSchedulerSelectionLease ||
        _fetchedSchedulerSelectionLease != null ||
        _schedulerSelectionLeaseError != null) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedSchedulerSelectionLease = null;
          _schedulerSelectionLeaseError =
              'Scheduler lease is waiting for a fresh validated client-instance session/resource observation.';
          _schedulerSelectionLeaseStale = false;
        });
      }
      return;
    }
    if (_selected?.conversation.id != null &&
        _selected?.conversation.id != expectedConversationID) {
      if (mounted) _update(_clearSchedulerSelectionLease);
      return;
    }
    if (_selectedRun?.runID != null && _selectedRun?.runID != expectedRunID) {
      if (mounted) _update(_clearSchedulerSelectionLease);
      return;
    }
    if (!_schedulerSelectionRequestVisible(expectedConversationID)) {
      if (mounted) _update(_clearSchedulerSelectionLease);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          isRenewal ? 'Scheduler lease renewal' : 'Scheduler lease',
        );
    if (observationError != null) {
      if (mounted) {
        _update(() {
          _fetchedSchedulerSelectionLease = null;
          _schedulerSelectionLeaseError = observationError;
          _schedulerSelectionLeaseStale = false;
        });
      }
      return;
    }
    final generation = ++_schedulerSelectionLeaseGeneration;
    _update(() {
      _loadingSchedulerSelectionLease = true;
      _schedulerSelectionLeaseError = null;
      _schedulerSelectionLeaseStale = false;
    });
    try {
      final ForgeSchedulerSelectionLease lease;
      if (isRenewal) {
        final expectedRequest =
            ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(
              renewalRequest!.toJson(),
            );
        lease = ForgeSchedulerSelectionLease.fromJson(
          (await renewalReader!(expectedRequest, idempotencyKey)).toJson(),
        );
        if (!lease.isFor(
              expectedRequest.conversationID,
              expectedRequest.runID,
              expectedRequest.attemptID,
            ) ||
            lease.instanceID != expectedRequest.targetID ||
            lease.grant.epoch <= expectedRequest.epoch ||
            !lease.authority.placementSelected ||
            !lease.authority.reservationCreated ||
            !lease.authority.leaseIssued ||
            lease.authority.executionAuthorized ||
            lease.authority.dispatchPerformed ||
            lease.authority.auditPublished) {
          throw const FormatException(
            'Forge returned an invalid scheduler lease renewal.',
          );
        }
      } else {
        final expectedRequest = ForgeSchedulerSelectionLeaseRequest.fromJson(
          request!.toJson(),
        );
        lease = ForgeSchedulerSelectionLease.fromJson(
          (await reader!(expectedRequest, idempotencyKey)).toJson(),
        );
        if (!lease.isFor(
              expectedRequest.conversationID,
              expectedRequest.runID,
              expectedRequest.attemptID,
            ) ||
            !lease.authority.placementSelected ||
            !lease.authority.reservationCreated ||
            !lease.authority.leaseIssued ||
            lease.authority.executionAuthorized ||
            lease.authority.dispatchPerformed ||
            lease.authority.auditPublished) {
          throw const FormatException(
            'Forge returned an invalid scheduler lease.',
          );
        }
      }
      if (lease.authority.executionAuthorized ||
          lease.authority.dispatchPerformed ||
          lease.authority.auditPublished) {
        throw const FormatException(
          'Forge returned an invalid scheduler lease.',
        );
      }
      if (!mounted ||
          generation != _schedulerSelectionLeaseGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSchedulerSelectionLease = lease;
        _schedulerSelectionLeaseError = null;
        _schedulerSelectionLeaseStale = false;
        _loadingSchedulerSelectionLease = false;
      });
    } catch (error) {
      if (!mounted || generation != _schedulerSelectionLeaseGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _schedulerSelectionLeaseGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSchedulerSelectionLease = null;
        _schedulerSelectionLeaseError = _friendlyError(
          error,
          isRenewal
              ? 'Could not renew scheduler lease.'
              : 'Could not claim scheduler lease.',
        );
        _schedulerSelectionLeaseStale = false;
        _loadingSchedulerSelectionLease = false;
      });
    }
  }

  void _clearSchedulerSelectionLease() {
    _schedulerSelectionLeaseGeneration++;
    _fetchedSchedulerSelectionLease = null;
    _schedulerSelectionLeaseError = null;
    _schedulerSelectionLeaseStale = false;
    _loadingSchedulerSelectionLease = false;
  }

  Future<void> _loadSchedulerSelectionLeaseReleaseIfRequested() async {
    final request = widget.schedulerSelectionLeaseReleaseRequest;
    final reader = widget.schedulerSelectionLeaseReleaseReader;
    final idempotencyKey = widget.schedulerSelectionLeaseReleaseIdempotencyKey;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        idempotencyKey == null ||
        idempotencyKey.trim().isEmpty) {
      if (mounted &&
          (_fetchedSchedulerSelectionLeaseRelease != null ||
              _schedulerSelectionLeaseReleaseError != null ||
              _loadingSchedulerSelectionLeaseRelease)) {
        _update(_clearSchedulerSelectionLeaseRelease);
      }
      return;
    }
    if (!_schedulerSelectionRequestVisible(request.conversationID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionLeaseRelease != null ||
              _schedulerSelectionLeaseReleaseError != null ||
              _loadingSchedulerSelectionLeaseRelease)) {
        _update(_clearSchedulerSelectionLeaseRelease);
      }
      return;
    }
    // Release is also a selected-session display/action candidate. Do not
    // release a proof for a different Conversation or Run after the Sessions
    // selection has moved; the empty/default Gate remains request-compatible.
    final selectedConversationID = _selected?.conversation.id;
    final selectedRunID = _selectedRun?.runID;
    if ((selectedConversationID != null &&
            selectedConversationID != request.conversationID) ||
        (selectedRunID != null && selectedRunID != request.runID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionLeaseRelease != null ||
              _schedulerSelectionLeaseReleaseError != null ||
              _loadingSchedulerSelectionLeaseRelease)) {
        _update(_clearSchedulerSelectionLeaseRelease);
      }
      return;
    }
    if (_loadingSchedulerSelectionLeaseRelease ||
        _fetchedSchedulerSelectionLeaseRelease != null ||
        _schedulerSelectionLeaseReleaseError != null) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) _update(_clearSchedulerSelectionLeaseRelease);
      return;
    }
    if (_selected?.conversation.id != null &&
        _selected?.conversation.id != request.conversationID) {
      if (mounted) _update(_clearSchedulerSelectionLeaseRelease);
      return;
    }
    if (_selectedRun?.runID != null && _selectedRun?.runID != request.runID) {
      if (mounted) _update(_clearSchedulerSelectionLeaseRelease);
      return;
    }
    if (!_schedulerSelectionRequestVisible(request.conversationID)) {
      if (mounted) _update(_clearSchedulerSelectionLeaseRelease);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Scheduler lease release',
        );
    if (observationError != null) {
      if (mounted) {
        _update(() {
          _fetchedSchedulerSelectionLeaseRelease = null;
          _schedulerSelectionLeaseReleaseError = observationError;
          _schedulerSelectionLeaseReleaseStale = false;
        });
      }
      return;
    }
    final generation = ++_schedulerSelectionLeaseReleaseGeneration;
    _update(() {
      _loadingSchedulerSelectionLeaseRelease = true;
      _schedulerSelectionLeaseReleaseError = null;
      _schedulerSelectionLeaseReleaseStale = false;
    });
    try {
      final expectedRequest =
          ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(request.toJson());
      final release = ForgeSchedulerSelectionLeaseRelease.fromJson(
        (await reader(expectedRequest, idempotencyKey)).toJson(),
      );
      if (!release.isFor(
            expectedRequest.conversationID,
            expectedRequest.runID,
            expectedRequest.attemptID,
          ) ||
          release.instanceID != expectedRequest.targetID ||
          release.epoch != expectedRequest.epoch ||
          release.authority.placementSelected ||
          release.authority.reservationCreated ||
          release.authority.leaseIssued ||
          release.authority.executionAuthorized ||
          release.authority.dispatchPerformed ||
          release.authority.auditPublished) {
        throw const FormatException(
          'Forge returned an invalid scheduler lease release.',
        );
      }
      if (!mounted ||
          generation != _schedulerSelectionLeaseReleaseGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSchedulerSelectionLeaseRelease = release;
        _schedulerSelectionLeaseReleaseError = null;
        _schedulerSelectionLeaseReleaseStale = false;
        _loadingSchedulerSelectionLeaseRelease = false;
      });
    } catch (error) {
      if (!mounted || generation != _schedulerSelectionLeaseReleaseGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _schedulerSelectionLeaseReleaseGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSchedulerSelectionLeaseRelease = null;
        _schedulerSelectionLeaseReleaseError = _friendlyError(
          error,
          'Could not release scheduler lease.',
        );
        _schedulerSelectionLeaseReleaseStale = false;
        _loadingSchedulerSelectionLeaseRelease = false;
      });
    }
  }

  void _clearSchedulerSelectionLeaseRelease() {
    _schedulerSelectionLeaseReleaseGeneration++;
    _fetchedSchedulerSelectionLeaseRelease = null;
    _schedulerSelectionLeaseReleaseError = null;
    _schedulerSelectionLeaseReleaseStale = false;
    _loadingSchedulerSelectionLeaseRelease = false;
  }
}
