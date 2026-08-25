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
          if (_preferences.isNotEmpty || _preferencesError)
            _preferencesCard(context),
        ],
      ],
    ),
  );

  Widget _notificationsHeader(BuildContext context) {
    final theme = Theme.of(context);
    final actionsDisabled =
        _loading ||
        _loadInFlight ||
        _loadingMore ||
        _markingAll ||
        _saving ||
        _markingReadIds.isNotEmpty ||
        _preferencesLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          context.tr('{count} unread security and account notifications.', {
            'count': formatCount(_unread),
          }),
          softWrap: true,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              if (_unread > 0)
                TextButton.icon(
                  onPressed: actionsDisabled ? null : _markAllRead,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: _markingAll
                      ? const Icon(Icons.hourglass_top_outlined, size: 18)
                      : const SizedBox.shrink(),
                  label: Text(context.tr('Mark all as read')),
                ),
              IconButton(
                onPressed: actionsDisabled ? null : _load,
                tooltip: context.tr('Refresh notifications'),
                icon: const Icon(Icons.refresh),
                color: theme.colorScheme.primary,
              ),
            ],
          ),
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
          child: _NotificationTile(
            item: item,
            busy: _markingReadIds.contains(item['id']?.toString()),
            onTap: () => _markRead(item),
          ),
        ),
      if (_hasMore) _loadMoreButton(context),
    ];
  }

  Widget _loadMoreButton(BuildContext context) {
    final failed = _loadMoreError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failed) MessageBanner(_loadMoreError),
        Align(
          alignment: Alignment.center,
          child: failed
              ? OutlinedButton.icon(
                  onPressed:
                      _loadingMore ||
                          _loadInFlight ||
                          _markingAll ||
                          _markingReadIds.isNotEmpty ||
                          _saving ||
                          _preferencesLoading
                      ? null
                      : () => _load(more: true),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.tr('Retry')),
                )
              : TextButton(
                  onPressed:
                      _loadingMore ||
                          _loadInFlight ||
                          _markingAll ||
                          _markingReadIds.isNotEmpty ||
                          _saving ||
                          _preferencesLoading
                      ? null
                      : () => _load(more: true),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: _loadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('Load more')),
                ),
        ),
      ],
    );
  }

  Widget _preferencesCard(BuildContext context) => PortalCard(
    title: 'Notification preferences',
    children: _preferencesError
        ? [
            MessageBanner('Notifications are not available.'),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving || _preferencesLoading
                    ? null
                    : _loadPreferences,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('Retry')),
              ),
            ),
          ]
        : [
            for (final preference in _preferences)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.tr(_typeLabel(preference['type']?.toString() ?? '')),
                ),
                subtitle: Text(
                  context.tr(
                    _channelLabel(preference['channel']?.toString() ?? ''),
                  ),
                ),
                value: preference['enabled'] != false,
                onChanged: _saving
                    ? null
                    : (value) => _setPreferenceEnabled(preference, value),
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
