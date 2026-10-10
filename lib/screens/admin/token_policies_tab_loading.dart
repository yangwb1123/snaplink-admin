part of 'token_policies_tab.dart';

extension _TokenPoliciesTabLoading on _TokenPoliciesTabState {
  Future<void> _load() async {
    final seq = ++_reqSeq;
    // ignore: invalid_use_of_protected_member
    setState(() {
      _loading = true;
      _error = null;
      _policies = const [];
      _page = 1;
    });
    try {
      final data = await widget.api.get(
        _TokenPoliciesTabState._path,
        forceRefresh: true,
      );
      final raw =
          data['policies'] as List? ?? data['token_policies'] as List? ?? [];
      final policies = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted || seq != _reqSeq) return;
      // ignore: invalid_use_of_protected_member
      setState(() {
        _policies = policies;
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
}
