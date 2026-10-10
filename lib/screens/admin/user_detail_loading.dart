part of 'user_detail_screen.dart';

extension _UserDetailLoading on _UserDetailScreenState {
  Future<void> _load() async {
    final seq = ++_reqSeq;
    final tabs = _tabs;
    final section = tabs.isEmpty
        ? null
        : tabs[_tabIndex.clamp(0, tabs.length - 1)].$1;
    // ignore: invalid_use_of_protected_member
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.client.getUser(widget.userId);
      if (!mounted || seq != _reqSeq) return;
      final data = section == null || section == 'device-security'
          ? null // Device security is an independently loading panel.
          : await _optionalGet(section, _userTabPath(section), seq);
      if (!mounted || seq != _reqSeq) return;
      // ignore: invalid_use_of_protected_member
      setState(() {
        _user = user;
        switch (section) {
          case 'sessions':
            _sessions = data;
          case 'consents':
            _consents = data;
          case 'mfa':
            _mfa = data;
          case 'lifecycle':
            _lifecycle = data;
        }
        _loading = false;
      });
    } catch (error) {
      if (mounted && seq == _reqSeq) {
        // ignore: invalid_use_of_protected_member
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  String _userTabPath(String tab) => switch (tab) {
    'sessions' => AdminPaths.userSessions(widget.userId),
    'consents' => AdminPaths.userConsents(widget.userId),
    'mfa' => AdminPaths.userMfa(widget.userId),
    'lifecycle' => AdminPaths.userLifecycle(widget.userId),
    _ => throw ArgumentError.value(tab, 'tab', 'Unsupported user tab'),
  };

  Future<Map<String, dynamic>> _optionalGet(
    String section,
    String path,
    int seq,
  ) async {
    try {
      final result = await widget.api.get(path, forceRefresh: true);
      if (mounted && seq == _reqSeq) _sectionErrors.remove(section);
      return result;
    } catch (error) {
      if (mounted && seq == _reqSeq) _sectionErrors[section] = error.toString();
      return <String, dynamic>{};
    }
  }
}
