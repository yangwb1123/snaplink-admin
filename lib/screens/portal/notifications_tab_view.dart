part of 'notifications_tab.dart';

extension _NotificationsTabView on _NotificationsTabState {
  Widget _buildNotificationsTab(BuildContext context) => PullToRefresh(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _notificationsHeader(context),
        const SizedBox(height: 8),
        if (_loading)
          const SkeletonListTile(itemCount: 3)
        else ...[
          _inboxCard(context),
          if (_preferences.isNotEmpty) _preferencesCard(context),
        ],
      ],
    ),
  );

  Widget _notificationsHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(
                  context.tr('Notifications'),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Text(
                context.tr(
                  '{count} unread security and account notifications.',
                  {'count': formatCount(_unread)},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (_unread > 0)
          TextButton(
            onPressed: _loading ? null : _markAllRead,
            child: Text(context.tr('Mark all as read')),
          ),
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: context.tr('Refresh notifications'),
          icon: const Icon(Icons.refresh),
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _inboxCard(BuildContext context) =>
      PortalCard(title: 'Inbox', children: _inboxChildren(context));

  List<Widget> _inboxChildren(BuildContext context) {
    if (_error != null) {
      return [
        MessageBanner(_error),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(context.tr('Retry')),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const [
        EmptyState(
          compact: true,
          icon: Icons.notifications_off_outlined,
          title: 'You have no notifications.',
        ),
      ];
    }
    return [
      for (final (index, item) in _items.indexed)
        StaggeredFadeIn(
          index: index,
          child: _NotificationTile(item: item, onTap: () => _markRead(item)),
        ),
      if (_hasMore) _loadMoreButton(context),
    ];
  }

  Widget _loadMoreButton(BuildContext context) => TextButton(
    onPressed: _loadingMore ? null : () => _load(more: true),
    child: _loadingMore
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(context.tr('Load more')),
  );

  Widget _preferencesCard(BuildContext context) => PortalCard(
    title: 'Notification preferences',
    children: [
      for (final preference in _preferences)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.tr(_typeLabel(preference['type']?.toString() ?? '')),
          ),
          subtitle: Text(
            context.tr(_channelLabel(preference['channel']?.toString() ?? '')),
          ),
          value: preference['enabled'] != false,
          onChanged: (value) => _setPreferenceEnabled(preference, value),
        ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _saving ? null : _savePreferences,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(context.tr('Save preferences')),
        ),
      ),
    ],
  );
}
