part of 'admin_live_events_tab.dart';

extension _AdminLiveEventsTabView on _AdminLiveEventsTabState {
  Widget _buildAdminLiveEventsTab(BuildContext context) {
    // Fixed header block; the data-driven feed rows below are rendered lazily
    // so each incoming SSE event rebuilds only visible rows. Scroll semantics
    // and the bounded 50-event retention are unchanged.
    final header = _liveEventsHeader(context);
    // Loading / empty tails are a handful of widgets and stay eager; the
    // event rows are the lazy part.
    final tail = _events.isNotEmpty ? const <Widget>[] : _feedTail();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount:
          header.length + (_events.isNotEmpty ? _events.length : tail.length),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        if (_events.isNotEmpty) {
          return _eventRow(context, _events[index - header.length]);
        }
        return tail[index - header.length];
      },
    );
  }

  List<Widget> _liveEventsHeader(BuildContext context) => [
    AdminBreadcrumb(),
    const SizedBox(height: 4),
    _liveEventsTitle(context),
    const SizedBox(height: 8),
    LocalizedText(
      _advertised
          ? 'The replica advertises the event broker. The feed shows only Snaplink\'s redacted event summaries; select an item to request its full audit record.'
          : 'The documented event broker is not listed by this replica\'s inventory. You can connect when the route is mounted; otherwise use audit queries.',
    ),
    const SizedBox(height: 16),
    _eventFilters(),
    const SizedBox(height: 12),
    _connectionActions(),
    if (_error != null) ...[const SizedBox(height: 12), _errorCard()],
    const SizedBox(height: 16),
    _connectionStatus(context),
    const SizedBox(height: 16),
    SectionHeader(
      'Live event feed',
      count: _events.isEmpty ? null : _events.length,
    ),
    const SizedBox(height: 8),
  ];

  Widget _liveEventsTitle(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.sensors_outlined, color: _accent),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              AppStrings.of(context).liveActivity,
              style: theme.textTheme.headlineSmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _eventFilters() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      SizedBox(
        width: 280,
        child: TextField(
          controller: _typesCtrl,
          enabled: !_connecting && !_connected,
          decoration: InputDecoration(
            labelText: 'Event types'.localized,
            helperText: 'Comma-separated; empty includes all types.'.localized,
          ),
        ),
      ),
      SizedBox(
        width: 280,
        child: TextField(
          controller: _tenantCtrl,
          enabled: !_connecting && !_connected,
          decoration: InputDecoration(
            labelText: 'Tenant ID (optional)'.localized,
          ),
        ),
      ),
    ],
  );

  Widget _connectionActions() => Wrap(
    spacing: 8,
    children: [
      FilledButton.icon(
        onPressed: _connecting || _connected ? null : _connect,
        icon: const Icon(Icons.play_arrow),
        label: LocalizedText(_connecting ? 'Connecting…' : 'Connect'),
      ),
      OutlinedButton.icon(
        onPressed: _connected || _connecting ? _disconnect : null,
        icon: const Icon(Icons.stop),
        label: const LocalizedText('Disconnect'),
      ),
      TextButton(
        onPressed: _events.isEmpty ? null : _clearFeed,
        child: const LocalizedText('Clear feed'),
      ),
    ],
  );

  Widget _connectionStatus(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _connectionChip(context),
        if (_connected) ...[
          const SizedBox(height: 8),
          LocalizedText(
            'Connected · latest {count} events are retained locally.',
            args: {'count': _AdminLiveEventsTabState._maximumEvents},
            style: theme.textTheme.titleSmall,
          ),
        ],
      ],
    );
  }

  Widget _connectionChip(BuildContext context) {
    if (_connecting) {
      return StatusChip(
        label: context.tr('Connecting…'),
        color: AppColors.accentBlue,
        icon: Icons.sync,
      );
    }
    return StatusChip(
      label: context.tr(_connected ? 'Connected' : 'Disconnected'),
      color: _connected ? AppColors.success : AppColors.muted,
      icon: _connected ? Icons.wifi : Icons.wifi_off,
    );
  }

  /// Error banner; Retry covers terminal stops (e.g. 401), auto-reconnect
  /// carries its countdown in the message.
  Widget _errorCard() => ErrorStateCard(
    message: _error!,
    onRetry: _reconnectWanted ? null : _connect,
  );

  /// Loading / empty states for the feed. Event rows are deliberately not
  /// built here: [_buildAdminLiveEventsTab] renders them lazily through
  /// [ListView.builder] so a rebuild on each incoming SSE event only mounts
  /// the visible rows instead of the whole retained feed (bounded at 50).
  List<Widget> _feedTail() {
    if (_connecting) return const [SkeletonListTile(itemCount: 4)];
    return const [
      EmptyState(
        variant: EmptyStateVariant.empty,
        title: 'No events received yet.',
      ),
    ];
  }

  /// Tappable row keeps the monospace id for the detail-read interaction.
  Widget _eventRow(BuildContext context, SnaplinkAdminEvent event) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: () => _showDetail(event),
        leading: Icon(Icons.notifications_outlined, color: _accent),
        title: Text(event.data['type']?.toString() ?? event.type),
        subtitle: Text(_summary(event)),
        trailing: event.id == null
            ? null
            : Text(
                event.id!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
      ),
    );
  }
}
