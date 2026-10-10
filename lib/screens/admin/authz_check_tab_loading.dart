part of 'authz_check_tab.dart';

extension _AuthzCheckLoading on _AuthzCheckTabState {
  void _invalidateRebac() => _update(() {
    _rebacSeq++;
    _rebacLoading = false;
    _rebacError = null;
    _rebacResult = null;
  });

  void _invalidateWasm() => _update(() {
    _wasmSeq++;
    _wasmLoading = false;
    _wasmError = null;
    _wasmResult = null;
  });

  Future<void> _checkRebac() async {
    final seq = ++_rebacSeq;
    _update(() {
      _rebacLoading = true;
      _rebacError = null;
      _rebacResult = null;
      _lastRan = 'rebac';
    });
    try {
      final raw = jsonDecode(_rebacCtrl.text);
      if (raw is! Map) throw const FormatException();
      final query = <String, String>{};
      for (final key in const ['object', 'relation', 'subject']) {
        final value = raw[key];
        if (value is! String || value.trim().isEmpty) {
          throw const FormatException();
        }
        query[key] = value.trim();
      }
      final result = await widget.api.get(
        _AuthzCheckTabState._rebacPath,
        query: query,
        forceRefresh: true,
      );
      if (!mounted || seq != _rebacSeq) return;
      _update(() {
        _rebacResult = result;
        _rebacLoading = false;
      });
    } catch (error) {
      if (!mounted || seq != _rebacSeq) return;
      _update(() {
        _rebacError = error is SnaplinkAdminApiError
            ? error.toString()
            : 'Invalid JSON or request failed.';
        _rebacLoading = false;
      });
    }
  }

  Future<void> _checkWasm() async {
    final seq = ++_wasmSeq;
    _update(() {
      _wasmLoading = true;
      _wasmError = null;
      _wasmResult = null;
      _lastRan = 'wasm';
    });
    try {
      final raw = jsonDecode(_wasmCtrl.text);
      if (raw is! Map<String, dynamic>) throw const FormatException();
      for (final key in const ['subject', 'action', 'resource']) {
        if (raw[key] is! String) throw const FormatException();
      }
      final context = raw['context'];
      if (context != null &&
          (context is! Map ||
              context.values.any((value) => value is! String))) {
        throw const FormatException();
      }
      final result = await widget.api.post(_AuthzCheckTabState._wasmPath, raw);
      if (!mounted || seq != _wasmSeq) return;
      _update(() {
        _wasmResult = result;
        _wasmLoading = false;
      });
    } catch (error) {
      if (!mounted || seq != _wasmSeq) return;
      _update(() {
        _wasmError = error is SnaplinkAdminApiError
            ? error.toString()
            : 'Use string subject, action and resource, with optional string context values.';
        _wasmLoading = false;
      });
    }
  }
}
