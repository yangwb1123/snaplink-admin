part of 'commerce_tab.dart';

extension _CommerceCheckoutFlow on _CommerceTabState {
  Future<void> _createTopUp() async {
    final body = await CommerceTopUpDialog.show(context, _currency.text);
    if (body == null ||
        !await _confirmFinancial('Create pending order and open checkout?')) {
      return;
    }
    await _createTopUpAndCheckout(body);
  }

  Future<void> _createTopUpAndCheckout(Map<String, dynamic> body) async {
    String? orderID;
    var refreshed = false;
    _update(() => _mutating = true);
    try {
      final response = await _commerce.createTopUp(_tenant.text.trim(), {
        ...body,
        'provider': 'stripe',
      });
      orderID = commerceCheckoutOrderID(response);
      await _openCheckout(orderID);
    } catch (error) {
      if (orderID == null) {
        orderID = await _recoverPendingOrder(
          body['idempotency_key']?.toString() ?? '',
        );
        refreshed = true;
      }
      await _checkoutFailure(orderID, error, refresh: !refreshed);
    } finally {
      if (mounted) _update(() => _mutating = false);
    }
  }

  Future<void> _retryCheckout(Map<String, dynamic> order) async {
    final orderID = order['id']?.toString().trim() ?? '';
    if (orderID.isEmpty ||
        !await _confirmFinancial('Continue pending top-up checkout?')) {
      return;
    }
    _update(() => _mutating = true);
    try {
      await _openCheckout(orderID);
    } catch (error) {
      await _checkoutFailure(orderID, error);
    } finally {
      if (mounted) _update(() => _mutating = false);
    }
  }

  Future<void> _openCheckout(String orderID) async {
    if (_checkoutProbe != CheckoutProbeState.available) {
      // P0-1: never fire the checkout POST into a replica that does not
      // serve the session endpoint — the order stays pending and the copy
      // below tells the operator why (dead-end-free).
      throw const CommerceCheckoutUnavailable();
    }
    final origin = widget.checkoutOrigin?.call() ?? ProductApiOrigin.baseUri;
    final urls = CommerceCheckoutUrls.fromOrigin(origin);
    final response = await _commerce.createCheckout(
      _tenant.text.trim(),
      orderID,
      urls.success,
      urls.cancel,
    );
    final redirect = commerceCheckoutRedirect(response);
    final navigate =
        widget.checkoutNavigator ?? BrowserNavigation.assignExternalLocation;
    if (!navigate(redirect)) {
      throw const CommerceCheckoutNavigationUnavailable();
    }
  }

  Future<String?> _recoverPendingOrder(String idempotencyKey) async {
    if (!mounted || !_tenantLoaded || idempotencyKey.isEmpty) return null;
    await _loadTenant();
    if (!mounted) return null;
    for (final order in _orders) {
      if (order['idempotency_key'] == idempotencyKey &&
          order['status'] == 'pending' &&
          order['provider'] == 'stripe') {
        final id = order['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  Future<void> _checkoutFailure(
    String? orderID,
    Object error, {
    bool refresh = true,
  }) async {
    if (!mounted) return;
    if (refresh && orderID != null && _tenantLoaded) await _loadTenant();
    if (!mounted) return;
    final message = switch (error) {
      CommerceCheckoutUnavailable() =>
        'Secure checkout is not enabled on the connected replica. The pending order is saved; use it when the billing service is available.',
      CommerceCheckoutNavigationUnavailable() =>
        'The pending order is saved. Secure checkout navigation is available only in a browser; open this console in a browser and continue the order.',
      _ when orderID != null =>
        'The pending order is saved, but secure checkout could not be started. Use Continue secure checkout on that order to retry.',
      _ =>
        'The top-up request outcome is unknown. Refresh tenant commerce before trying again. No payment details were collected.',
    };
    _update(() => _tenantError = message);
  }
}
