part of 'admin_live_events_tab.dart';

extension _AdminLiveEventsTabView on _AdminLiveEventsTabState {
  Widget _buildAdminLiveEventsTab(BuildContext context) {
    // Fixed header block; the data-driven feed rows below are rendered lazily
    // so each incoming SSE event rebuilds only visible rows. Scroll semantics
    // and the bounded 50-event retention are unchanged.
    final header = _liveEventsHeader(context);
    final visibleEvents = _visibleEvents;
    // Loading / empty tails are a handful of widgets and stay eager; the
    // retained event rows are the lazy part. A local search only changes this
    // bounded view; it never creates pages or changes the SSE cursor.
    final tail = visibleEvents.isNotEmpty ? const <Widget>[] : _feedTail();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount:
          header.length +
          (visibleEvents.isNotEmpty ? visibleEvents.length : tail.length),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        if (visibleEvents.isNotEmpty) {
          return _eventRow(context, visibleEvents[index - header.length]);
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
      count: _events.isEmpty ? null : _visibleEvents.length,
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
          enabled: !_connecting && !_connected && !_reconnectWanted,
          textInputAction: TextInputAction.next,
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
          enabled: !_connecting && !_connected && !_reconnectWanted,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Tenant ID (optional)'.localized,
          ),
        ),
      ),
      SizedBox(
        width: 280,
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search'.localized,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear filter'.localized,
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
      ),
    ],
  );

  Widget _connectionActions() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton.icon(
        onPressed: _connecting || _connected ? null : _connect,
        icon: const Icon(Icons.play_arrow),
        label: LocalizedText(_connecting ? 'Connecting…' : 'Connect'),
      ),
      OutlinedButton.icon(
        // This also cancels an automatic reconnect timer. A live stream must
        // always have an explicit operator cancellation path.
        onPressed: _reconnectWanted ? _disconnect : null,
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _connectionChip(context),
        if (_connected)
          LocalizedText(
            'Connected · latest {count} events are retained locally.',
            args: {'count': _AdminLiveEventsTabState._maximumEvents},
            style: theme.textTheme.titleSmall,
          ),
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
    if (_events.isNotEmpty && _visibleEvents.isEmpty) {
      return [
        EmptyState(
          variant: EmptyStateVariant.noMatch,
          title: 'No matching events.',
          actionLabel: 'Clear filter',
          actionIcon: Icons.filter_alt_off,
          onAction: _clearSearch,
        ),
      ];
    }
    return const [
      EmptyState(
        variant: EmptyStateVariant.empty,
        title: 'No events received yet.',
      ),
    ];
  }

  /// Tappable row keeps the monospace id for the detail-read interaction.
  /// The id moves into the subtitle on narrow screens so it does not compete
  /// with the summary for a fixed trailing column.
  Widget _eventRow(BuildContext context, SnaplinkAdminEvent event) {
    final theme = Theme.of(context);
    final id = _eventId(event);
    final title = event.data['type']?.toString() ?? event.type;
    final summary = _summary(event);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final idText = id == null
            ? null
            : Text(
                id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              );
        final subtitle = narrow && idText != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  idText,
                ],
              )
            : Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis);
        return Card(
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: id != null,
            label: [title, summary, ?id].join('. '),
            hint: id == null ? null : context.tr('View details'),
            onTap: id == null ? null : () => _showDetail(event),
            child: ListTile(
              onTap: id == null ? null : () => _showDetail(event),
              leading: Icon(Icons.notifications_outlined, color: _accent),
              title: Text(title),
              subtitle: subtitle,
              trailing: narrow
                  ? idText == null
                        ? null
                        : const Icon(Icons.chevron_right)
                  : idText,
            ),
          ),
        );
      },
    );
  }
}
