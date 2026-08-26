part of 'commerce_tab.dart';

extension _CommerceTabView on _CommerceTabState {
  Widget _buildCommerceTab(BuildContext context) => PullToRefresh(
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: 'Commercial subscriptions and quotas',
          subtitle:
              'Manage immutable plan versions, tenant subscriptions, projected entitlements, wallet ledger entries, and normalized payment facts.',
          onRefresh: _refresh,
          actions: [
            IconButton(
              onPressed: _catalogLoading || _tenantLoading ? null : _refresh,
              icon: (_catalogLoading || _tenantLoading)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh, color: _accent),
              tooltip: 'Refresh'.localized,
            ),
          ],
        ),
        if (widget.availabilityError != null)
          CommerceErrorCard(
            message: widget.availabilityError.toString(),
            onRetry: _catalogLoading ? null : _loadPlans,
          ),
        if (_catalogError != null)
          CommerceErrorCard(message: _catalogError!, onRetry: _loadPlans),
        if (_catalogLoading)
          const SkeletonListTile(itemCount: 2, variant: SkeletonVariant.card),
        const SizedBox(height: 12),
        CommercePlansPanel(
          plans: _plans,
          onPublish: _mutating ? null : _publishPlan,
        ),
        const SizedBox(height: 12),
        CommerceTenantSelector(
          tenant: _tenant,
          currency: _currency,
          enabled: !_tenantLoading && !_mutating,
          onLoad: _loadTenant,
        ),
        if (_tenantError != null)
          CommerceErrorCard(
            message: _tenantError!,
            onRetry: _tenantLoading ? null : _loadTenant,
          ),
        if (_tenantLoading)
          const SkeletonListTile(itemCount: 3, variant: SkeletonVariant.card),
        if (_tenantLoaded && !_tenantLoading) ...[
          const SizedBox(height: 12),
          CommerceSubscriptionsPanel(
            subscriptions: _subscriptions,
            onCreate: _mutating ? null : _createSubscription,
            onStatus: _mutating ? null : _changeStatus,
            onChangePlan: _mutating ? null : _changePlan,
            onRenew: _mutating ? null : _renew,
          ),
          const SizedBox(height: 12),
          CommerceEntitlementPanel(entitlement: _entitlement),
          const SizedBox(height: 12),
          CommerceWalletPanel(
            currency: _currency.text,
            wallet: _wallet,
            entries: _entries,
            orders: _orders,
            eventOrderID: _eventOrderID,
            events: _events,
            reconciliation: _reconciliation,
            checkoutEnabled: _checkoutProbe == CheckoutProbeState.available,
            onAdjust: _mutating ? null : _adjustWallet,
            onTopUp: _mutating ? null : _createTopUp,
            onReconcile: _mutating ? null : _reconcile,
            onLoadEvents: _mutating ? null : _loadEvents,
            onCheckoutOrder: _mutating ? null : _retryCheckout,
          ),
        ],
      ],
    ),
  );
}
