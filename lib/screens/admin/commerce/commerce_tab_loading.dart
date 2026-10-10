part of 'commerce_tab.dart';

extension _CommerceTenantLoading on _CommerceTabState {
  void _onTenantQueryChanged() {
    final query = (_tenant.text.trim(), _currency.text.trim().toUpperCase());
    if (query == _tenantQuery) return;
    _tenantQuery = query;
    _update(() {
      _tenantSeq++;
      _tenantLoaded = false;
      _tenantLoading = false;
      _tenantError = null;
      _clearTenantData();
    });
  }

  void _clearTenantData() {
    _subscriptions = const [];
    _entitlement = null;
    _wallet = null;
    _entries = const [];
    _orders = const [];
    _events = const [];
    _eventOrderID = null;
    _reconciliation = null;
    _tenantSources.clear();
  }

  Future<void> _loadTenant() async {
    final tenantID = _tenant.text.trim();
    final currency = _currency.text.trim().toUpperCase();
    if (tenantID.isEmpty || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      _update(
        () => _tenantError =
            'Enter a tenant ID and a three-letter currency code.',
      );
      return;
    }
    _currency.text = currency;
    final seq = ++_tenantSeq;
    _update(() {
      _tenantLoading = true;
      _tenantLoaded = false;
      _tenantError = null;
      _clearTenantData();
    });
    final results = await Future.wait([
      _section(_commerce.listSubscriptions(tenantID), 'subscriptions'),
      _section(
        _commerce.getEntitlement(tenantID),
        'entitlement',
        allowMissing: true,
      ),
      _section(
        _commerce.getWallet(tenantID, currency),
        'wallet',
        allowMissing: true,
      ),
      _section(
        _commerce.listWalletEntries(tenantID, currency),
        'entries',
        allowMissing: true,
      ),
      _section(_commerce.listOrders(tenantID), 'orders'),
    ]);
    if (!mounted || seq != _tenantSeq) return;
    _update(() {
      final errors = results.map((result) => result.error).whereType<String>();
      for (final result in results) {
        if (result.error == null) _tenantSources.add(result.key);
      }
      _subscriptions = commerceRecords(
        results[0].data ?? const {},
        'subscriptions',
      );
      _entitlement = commerceRecord(results[1].data ?? const {}, 'entitlement');
      _wallet = commerceRecord(results[2].data ?? const {}, 'wallet');
      _entries = commerceRecords(results[3].data ?? const {}, 'entries');
      _orders = commerceRecords(results[4].data ?? const {}, 'orders');
      _tenantError = errors.isEmpty ? null : errors.join('\n');
      _tenantLoading = false;
      _tenantLoaded = true;
    });
  }

  Future<({String key, Map<String, dynamic>? data, String? error})> _section(
    Future<Map<String, dynamic>> request,
    String key, {
    bool allowMissing = false,
  }) async {
    try {
      return (key: key, data: await request, error: null);
    } catch (error) {
      if (allowMissing &&
          error is SnaplinkAdminApiError &&
          error.status == 404) {
        return (key: key, data: null, error: null);
      }
      return (key: key, data: null, error: '$key: $error');
    }
  }
}
