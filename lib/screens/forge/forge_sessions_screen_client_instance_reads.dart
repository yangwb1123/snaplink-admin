part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenClientInstanceReads on _ForgeSessionsScreenState {
  Future<void> _loadClientInstanceSessionResourceConvergenceIfRequested({
    bool force = false,
  }) async {
    final owner = widget.clientInstanceSessionResourceConvergenceOwner;
    final reader = widget.clientInstanceSessionResourceConvergenceReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedClientInstanceSessionResourceConvergence != null ||
              _clientInstanceSessionResourceConvergenceError != null ||
              _loadingClientInstanceSessionResourceConvergence)) {
        _update(_clearClientInstanceSessionResourceConvergence);
      }
      return;
    }
    if (_loadingClientInstanceSessionResourceConvergence) return;
    if (!force &&
        (_fetchedClientInstanceSessionResourceConvergence != null ||
            _clientInstanceSessionResourceConvergenceError != null)) {
      return;
    }
    final previous = _fetchedClientInstanceSessionResourceConvergence;
    final generation = ++_clientInstanceSessionResourceConvergenceGeneration;
    _update(() {
      _loadingClientInstanceSessionResourceConvergence = true;
      _clientInstanceSessionResourceConvergenceError = null;
      _clientInstanceSessionResourceConvergenceStale = previous != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final convergence =
          ForgeClientInstanceSessionResourceConvergence.fromJson(
            (await reader(owner)).toJson(),
          );
      if (convergence.owner != expectedOwner || !convergence.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid client-instance session/resource pair.',
        );
      }
      if (!mounted ||
          generation != _clientInstanceSessionResourceConvergenceGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedClientInstanceSessionResourceConvergence = convergence;
        _clientInstanceSessionResourceConvergenceError = null;
        _clientInstanceSessionResourceConvergenceStale = false;
        _loadingClientInstanceSessionResourceConvergence = false;
        _fetchedClientInstanceSessionView = convergence.sessionView;
        _clientInstanceSessionViewError = null;
        _clientInstanceSessionViewStale = false;
        _loadingClientInstanceSessionView = false;
        _fetchedClientInstanceResourceView = convergence.resourceView;
        _clientInstanceResourceViewError = null;
        _clientInstanceResourceViewStale = false;
        _loadingClientInstanceResourceView = false;
      });
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted ||
          generation != _clientInstanceSessionResourceConvergenceGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _clientInstanceSessionResourceConvergenceGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedClientInstanceSessionResourceConvergence = previous;
        _clientInstanceSessionResourceConvergenceError = _friendlyError(
          error,
          'Could not load client-instance session/resource observations.',
        );
        _clientInstanceSessionResourceConvergenceStale = previous != null;
        _loadingClientInstanceSessionResourceConvergence = false;
      });
    }
  }

  void _clearClientInstanceSessionResourceConvergence() {
    _clientInstanceSessionResourceConvergenceGeneration++;
    _fetchedClientInstanceSessionResourceConvergence = null;
    _clientInstanceSessionResourceConvergenceError = null;
    _clientInstanceSessionResourceConvergenceStale = false;
    _loadingClientInstanceSessionResourceConvergence = false;
  }

  Future<void> _loadClientInstanceSessionViewIfRequested({
    bool force = false,
  }) async {
    // A configured pair owns both projections. Do not fall back to two
    // independent reads during a forced refresh, otherwise the screen could
    // immediately replace a converged image with a mixed one.
    if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
        widget.clientInstanceSessionResourceConvergenceReader != null) {
      return;
    }
    final owner = widget.clientInstanceSessionViewOwner;
    final reader = widget.clientInstanceSessionViewReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedClientInstanceSessionView != null ||
              _clientInstanceSessionViewError != null ||
              _loadingClientInstanceSessionView)) {
        _update(_clearClientInstanceSessionView);
      }
      return;
    }
    if (_loadingClientInstanceSessionView) return;
    if (!force &&
        (_fetchedClientInstanceSessionView != null ||
            _clientInstanceSessionViewError != null)) {
      return;
    }
    final previousView = _fetchedClientInstanceSessionView;
    final generation = ++_clientInstanceSessionViewGeneration;
    _update(() {
      _loadingClientInstanceSessionView = true;
      _clientInstanceSessionViewError = null;
      _clientInstanceSessionViewStale = previousView != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final view = ForgeClientInstanceSessionView.fromJson(
        (await reader(owner)).toJson(),
      );
      if (view.owner != expectedOwner || !view.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid client-instance session view.',
        );
      }
      if (!mounted ||
          generation != _clientInstanceSessionViewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedClientInstanceSessionView = view;
        _clientInstanceSessionViewError = null;
        _clientInstanceSessionViewStale = false;
        _loadingClientInstanceSessionView = false;
      });
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted || generation != _clientInstanceSessionViewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _clientInstanceSessionViewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedClientInstanceSessionView = previousView;
        _clientInstanceSessionViewError = _friendlyError(
          error,
          'Could not load client-instance session view.',
        );
        _clientInstanceSessionViewStale = previousView != null;
        _loadingClientInstanceSessionView = false;
      });
    }
  }

  void _clearClientInstanceSessionView() {
    final hadActiveClientInstanceFilter = _selectedClientInstanceID != null;
    _clientInstanceSessionViewGeneration++;
    _fetchedClientInstanceSessionView = null;
    _clientInstanceSessionViewError = null;
    _clientInstanceSessionViewStale = false;
    _loadingClientInstanceSessionView = false;
    // Keep an active local filter while its session projection is being
    // revoked or replaced. Clearing it would broaden the list back to every
    // owner conversation during the gap; revoke the private Prompt/Run
    // details and let the renderer keep the projection empty until a new
    // declaration is available.
    if (hadActiveClientInstanceFilter) {
      _clearRunDetailsForHiddenClientInstance();
    }
  }

  Future<void> _loadClientInstanceResourceViewIfRequested({
    bool force = false,
  }) async {
    if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
        widget.clientInstanceSessionResourceConvergenceReader != null) {
      return;
    }
    final inFlight = _clientInstanceResourceViewRefresh;
    if (inFlight != null) {
      final inFlightWasForced = _clientInstanceResourceViewRefreshWasForced;
      await inFlight;
      if (!force ||
          (inFlightWasForced &&
              _clientInstanceResourceViewError == null &&
              !_clientInstanceResourceViewStale)) {
        return;
      }
    }
    final refresh = _loadClientInstanceResourceViewNow(force: force);
    _clientInstanceResourceViewRefresh = refresh;
    _clientInstanceResourceViewRefreshWasForced = force;
    try {
      await refresh;
    } finally {
      if (identical(_clientInstanceResourceViewRefresh, refresh)) {
        _clientInstanceResourceViewRefresh = null;
        _clientInstanceResourceViewRefreshWasForced = false;
      }
    }
  }

  Future<void> _loadClientInstanceResourceViewNow({bool force = false}) async {
    final owner = widget.clientInstanceResourceViewOwner;
    final reader = widget.clientInstanceResourceViewReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (owner == null || reader == null) {
      if (mounted &&
          (_fetchedClientInstanceResourceView != null ||
              _clientInstanceResourceViewError != null ||
              _loadingClientInstanceResourceView)) {
        _update(_clearClientInstanceResourceView);
      }
      return;
    }
    if (_loadingClientInstanceResourceView) return;
    if (!force &&
        (_fetchedClientInstanceResourceView != null ||
            _clientInstanceResourceViewError != null)) {
      return;
    }
    final previousView = _fetchedClientInstanceResourceView;
    final generation = ++_clientInstanceResourceViewGeneration;
    _update(() {
      _loadingClientInstanceResourceView = true;
      _clientInstanceResourceViewError = null;
      _clientInstanceResourceViewStale = previousView != null;
    });
    try {
      final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
      final view = ForgeClientInstanceResourceView.fromJson(
        (await reader(owner)).toJson(),
      );
      if (view.owner != expectedOwner || !view.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid client-instance resource view.',
        );
      }
      if (!mounted ||
          generation != _clientInstanceResourceViewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedClientInstanceResourceView = view;
        _clientInstanceResourceViewError = null;
        _clientInstanceResourceViewStale = false;
        _loadingClientInstanceResourceView = false;
      });
      _reconcileSelectedClientInstanceProjection();
    } catch (error) {
      if (!mounted || generation != _clientInstanceResourceViewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _clientInstanceResourceViewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedClientInstanceResourceView = previousView;
        _clientInstanceResourceViewError = _friendlyError(
          error,
          'Could not load client-instance resource view.',
        );
        _clientInstanceResourceViewStale = previousView != null;
        _loadingClientInstanceResourceView = false;
      });
    }
  }

  void _clearClientInstanceResourceView() {
    final hadActiveClientInstanceFilter = _selectedClientInstanceID != null;
    _clientInstanceResourceViewGeneration++;
    _fetchedClientInstanceResourceView = null;
    _clientInstanceResourceViewError = null;
    _clientInstanceResourceViewStale = false;
    _loadingClientInstanceResourceView = false;
    // Resource metadata drives the same local instance projection when no
    // dedicated session view is supplied. Revoke private Prompt/Run details
    // during a reader gap instead of allowing a restored resource declaration
    // to resurrect state fetched under the old projection.
    if (hadActiveClientInstanceFilter) {
      _clearRunDetailsForHiddenClientInstance();
    }
  }
}
