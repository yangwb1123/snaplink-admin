part of 'token_security_tab.dart';

extension _TokenSecurityTabLoading on _TokenSecurityTabState {
  bool _readsSource(String key) =>
      _currentSection == 'all' ||
      key == (_currentSection == 'revoke' ? 'tokens' : _currentSection);

  Future<void> _load() async {
    final seq = ++_reqSeq;
    // ignore: invalid_use_of_protected_member
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait(
      _TokenSecurityTabState._paths.entries
          .where((e) => _readsSource(e.key) && _supports('GET', e.value))
          .map((e) async {
            try {
              return (
                key: e.key,
                data: await widget.api.get(e.value, forceRefresh: true),
                error: null,
              );
            } catch (error) {
              return (key: e.key, data: null, error: error);
            }
          }),
    );
    if (!mounted || seq != _reqSeq) return;
    final failures = results
        .where((r) => r.error != null)
        .map((r) => '${r.key}: ${r.error}')
        .join('\n');
    // ignore: invalid_use_of_protected_member
    setState(() {
      _data
        ..clear()
        ..addEntries([
          for (final r in results)
            if (r.data != null) MapEntry(r.key, r.data!),
        ]);
      // Keep permission, contract and reachability errors diagnosable instead
      // of turning them into an empty list or an unavailable capability.
      _error = failures.isEmpty ? null : failures;
      _loading = false;
    });
  }
}
