part of 'permissions_tab.dart';

extension _PermissionsLoading on _PermissionsTabState {
  void _onClientChanged() {
    if (_inputClient == _clientId) return;
    _inputClient = _clientId;
    _update(() {
      _reqSeq++;
      _loadedClient = null;
      _loadedSources.clear();
      _loading = false;
      _error = null;
      _roles = const [];
      _assignments = const [];
      _userCtrl.clear();
      _roleCodesCtrl.clear();
      _menusCtrl.text = '[]';
    });
  }

  Future<void> _load() async {
    final seq = ++_reqSeq;
    final clientId = _clientId;
    _update(() {
      _loading = clientId != null;
      _loadedClient = null;
      _loadedSources.clear();
      _error = clientId == null ? 'Enter a client ID first.' : null;
      _roles = const [];
      _assignments = const [];
    });
    if (clientId == null) return;
    final spec = <String, String>{
      if (_supportsRoles &&
          (_currentSection == 'all' || _currentSection == 'roles'))
        'roles': AdminPaths.permissionRoles(clientId),
      if (_supportsAssignments &&
          (_currentSection == 'all' || _currentSection == 'assignments'))
        'assignments': AdminPaths.permissionAssignments(clientId),
    };
    final results = await Future.wait(
      spec.entries.map((entry) async {
        try {
          final data = await widget.api.get(entry.value, forceRefresh: true);
          return (key: entry.key, rows: _records(data[entry.key]), error: null);
        } catch (error) {
          return (
            key: entry.key,
            rows: <Map<String, dynamic>>[],
            error: '${entry.value}: $error',
          );
        }
      }),
    );
    if (!mounted || seq != _reqSeq) return;
    _update(() {
      final errors = <String>[];
      for (final result in results) {
        if (result.error case final String error) {
          errors.add(error);
        } else {
          _loadedSources.add(result.key);
          if (result.key == 'roles') _roles = result.rows;
          if (result.key == 'assignments') _assignments = result.rows;
        }
      }
      _error = errors.isEmpty ? null : errors.join('\n');
      _loadedClient = clientId;
      _loading = false;
    });
  }
}
