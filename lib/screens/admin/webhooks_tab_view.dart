part of 'webhooks_tab.dart';

extension _WebhooksTabView on _WebhooksTabState {
  Widget _buildWebhooksTab(BuildContext context) {
    if (!_hasSubscriptions && !_hasDeadLetters) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'Webhook management is not enabled on this replica.',
      );
    }
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBreadcrumb(),
          _header(context),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusFilterDropdown(
              value: _statusFilter,
              options: const {
                'all': 'All statuses',
                'active': 'Active only',
                'inactive': 'Inactive only',
              },
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                setState(() => _statusFilter = value);
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _errorCard(context),
          ],
          if (_hasSubscriptions) ...[
            const SizedBox(height: 12),
            _createCard(context),
            const SizedBox(height: 16),
            _subscriptionsCard(context),
            const SizedBox(height: 16),
          ],
          if (_hasDeadLetters) _deadLettersCard(context),
        ],
      ),
    );
  }

  /// 页头：模块组色图标 + 标题 + 副标题 + 刷新（X7）。
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.webhook, color: _accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    AppStrings.of(context).webhooks,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                LocalizedText(
                  'Manage event notification webhook subscriptions and dead letters.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh'.localized,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）；错误文本动态 Text（X10）。
  Widget _errorCard(BuildContext context) =>
      ErrorStateCard(message: _error!, onRetry: _load, retryEnabled: !_loading);

  Widget _createCard(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'Create subscription',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _field(
            _urlCtrl,
            label: 'Webhook URL',
            hint: 'https://hooks.example.com/events',
          ),
          const SizedBox(height: 12),
          _field(
            _eventsCtrl,
            label: 'Event types (comma-separated)',
            hint: 'user.created, session.revoked',
          ),
          const SizedBox(height: 12),
          _field(
            _secretCtrl,
            label: 'Signing secret (optional)',
            obscure: true,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LocalizedText('Active'),
            value: _active,
            onChanged: (v) {
              // ignore: invalid_use_of_protected_member
              setState(() => _active = v);
            },
          ),
          FilledButton(
            onPressed: () => AdminRoute.go('webhooks', action: 'new'),
            child: const LocalizedText('Create subscription'),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller, {
    required String label,
    String? hint,
    bool obscure = false,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    decoration: InputDecoration(
      labelText: label.localized,
      hintText: hint?.localized,
    ),
  );
}
