import 'package:sso_admin/api/snaplink_admin_api.dart';

enum CommerceProbeState { available, unavailable, degraded }

CommerceProbeState commerceProbeState(Object? error) {
  if (error == null) return CommerceProbeState.available;
  if (error is SnaplinkAdminApiError &&
      (error.status == 403 || error.status == 404)) {
    return CommerceProbeState.unavailable;
  }
  return CommerceProbeState.degraded;
}

class CommerceAdminApi {
  final SnaplinkAdminApi _api;

  const CommerceAdminApi(this._api);

  Future<Map<String, dynamic>> listPlans() =>
      _api.get('/api/v1/admin/commerce/plans', forceRefresh: true);

  Future<Map<String, dynamic>> publishPlan(Map<String, dynamic> body) =>
      _api.post('/api/v1/admin/commerce/plans', body);

  Future<Map<String, dynamic>> listSubscriptions(String tenantID) =>
      _api.get('${_tenantPath(tenantID)}/subscriptions', forceRefresh: true);

  Future<Map<String, dynamic>> createSubscription(
    String tenantID,
    Map<String, dynamic> body,
  ) => _api.post('${_tenantPath(tenantID)}/subscriptions', body);

  Future<Map<String, dynamic>> transitionSubscription(
    String subscriptionID,
    String status,
    int revision,
  ) => _api.patch('${_subscriptionPath(subscriptionID)}/status', {
    'status': status,
    'expected_revision': revision,
  });

  Future<Map<String, dynamic>> changePlan(
    String subscriptionID,
    String planID,
    int planVersion,
    int revision,
  ) => _api.patch('${_subscriptionPath(subscriptionID)}/plan', {
    'plan_id': planID,
    'plan_version': planVersion,
    'expected_revision': revision,
  });

  Future<Map<String, dynamic>> renewSubscription(
    String subscriptionID,
    int revision,
  ) => _api.post('${_subscriptionPath(subscriptionID)}/renew', {
    'expected_revision': revision,
  });

  Future<Map<String, dynamic>> getEntitlement(String tenantID) =>
      _api.get('${_tenantPath(tenantID)}/entitlement', forceRefresh: true);

  Future<Map<String, dynamic>> getWallet(String tenantID, String currency) =>
      _api.get(
        '${_tenantPath(tenantID)}/wallet',
        query: {'currency': currency},
      );

  Future<Map<String, dynamic>> listWalletEntries(
    String tenantID,
    String currency,
  ) => _api.get(
    '${_tenantPath(tenantID)}/wallet/entries',
    query: {'currency': currency, 'limit': '100'},
  );

  Future<Map<String, dynamic>> adjustWallet(
    String tenantID,
    Map<String, dynamic> body,
  ) => _api.post('${_tenantPath(tenantID)}/wallet/adjustments', body);

  Future<Map<String, dynamic>> listOrders(String tenantID) =>
      _api.get('${_tenantPath(tenantID)}/payments/orders', forceRefresh: true);

  Future<Map<String, dynamic>> createTopUp(
    String tenantID,
    Map<String, dynamic> body,
  ) => _api.post('${_tenantPath(tenantID)}/payments/orders', body);

  Future<Map<String, dynamic>> createCheckout(
    String tenantID,
    String orderID,
    Uri successURL,
    Uri cancelURL,
  ) => _api.post('/api/v1/checkout/sessions', {
    'tenant_id': tenantID,
    'order_id': orderID,
    'success_url': successURL.toString(),
    'cancel_url': cancelURL.toString(),
  });

  Future<Map<String, dynamic>> listPaymentEvents(
    String tenantID,
    String orderID,
  ) => _api.get(
    '${_tenantPath(tenantID)}/payments/orders/'
    '${Uri.encodeComponent(orderID)}/events',
    forceRefresh: true,
  );

  Future<Map<String, dynamic>> reconcile(String tenantID) =>
      _api.post('${_tenantPath(tenantID)}/payments/reconcile', {});

  static String _tenantPath(String tenantID) =>
      '/api/v1/admin/commerce/tenants/${Uri.encodeComponent(tenantID)}';

  static String _subscriptionPath(String subscriptionID) =>
      '/api/v1/admin/commerce/subscriptions/'
      '${Uri.encodeComponent(subscriptionID)}';
}
