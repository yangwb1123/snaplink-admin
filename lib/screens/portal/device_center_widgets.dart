part of 'devices_tab.dart';

extension _DeviceListView on _DevicesTabState {
  Widget _filters(BuildContext context) {
    if (_devices.isEmpty) return const SizedBox.shrink();
    final types = _filterValues(_deviceType);
    final statuses = _filterValues(_deviceStatus);
    if (_typeFilter != null && !types.contains(_typeFilter)) types.add(_typeFilter!);
    if (_statusFilter != null && !statuses.contains(_statusFilter)) {
      statuses.add(_statusFilter!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchFilterBar(
          key: const Key('portal-devices-search'),
          controller: _searchController,
          hintText: context.tr('Search devices...'),
          debounce: false,
          onSearchChanged: _onSearchChanged,
          onSubmitted: _onSearchChanged,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 440
                ? (constraints.maxWidth - 8) / 2
                : 180.0;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: width,
                  child: _filterDropdown(
                    context,
                    'Type',
                    types,
                    _typeFilter,
                    _setTypeFilter,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _filterDropdown(
                    context,
                    'Status',
                    statuses,
                    _statusFilter,
                    _setStatusFilter,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _filterDropdown(
                    context,
                    'Recent activity',
                    _DevicesTabState._activityFilters,
                    _activityFilter,
                    _setActivityFilter,
                  ),
                ),
                if (_hasActiveFilters)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _clearFilters,
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: Text(context.tr('Clear filter')),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _filterDropdown(
    BuildContext context,
    String label,
    List<String> values,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    final options = <String>['', ...values.where((value) => value.isNotEmpty)];
    final current = selected != null && options.contains(selected) ? selected : '';
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.tr(label), isDense: true),
      items: [
        DropdownMenuItem<String>(value: '', child: Text(context.tr('All'))),
        for (final value in values)
          if (value.isNotEmpty)
            DropdownMenuItem<String>(
              value: value,
              child: Text(value, overflow: TextOverflow.ellipsis),
            ),
      ],
      onChanged: (value) => onChanged(value == null || value.isEmpty ? null : value),
    );
  }

  List<AdminDataColumn> _columns(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) => [
    AdminDataColumn(
      id: 'device',
      label: context.tr('Device'),
      width: 176,
      sortable: true,
      cardPrimary: true,
      builder: (_, index) => Row(
        children: [
          _deviceIcon(context, rows[index]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _deviceName(rows[index]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
    AdminDataColumn(
      id: 'type',
      label: context.tr('Type'),
      width: 86,
      sortable: true,
      cardDetail: true,
      builder: (_, index) => Text(
        _deviceType(rows[index]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    AdminDataColumn(
      id: 'status',
      label: context.tr('Status'),
      width: 122,
      sortable: true,
      cardDetail: true,
      builder: (_, index) => _deviceState(rows[index]),
    ),
    AdminDataColumn(
      id: 'activity',
      label: context.tr('Recent activity'),
      width: 120,
      sortable: true,
      cardDetail: true,
      builder: (_, index) => Text(
        _activityText(context, rows[index]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    AdminDataColumn(
      id: 'sessions',
      label: context.tr('Sessions'),
      width: 100,
      cardDetail: true,
      builder: (_, index) => _activeSessionsChip(context, rows[index]),
    ),
    AdminDataColumn(
      id: 'actions',
      label: '',
      width: 72,
      builder: (_, index) => _deviceActions(context, rows[index]),
    ),
  ];

  Widget _deviceIcon(BuildContext context, Map<String, dynamic> device) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: _deviceType(device),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _deviceIconData(_deviceType(device)),
          color: color,
          size: 20,
        ),
      ),
    );
  }

  Widget _deviceState(Map<String, dynamic> device) {
    final status = _deviceStatus(device);
    final lower = status.toLowerCase();
    final label = _statusLabel(status);
    final statusChip = switch (lower) {
      'active' || 'online' || 'current' => StatusChip.active(label: label),
      'trusted' || 'healthy' => StatusChip.healthy(label: label),
      'pending' => StatusChip.pending(label: label),
      'suspicious' || 'warning' || 'degraded' =>
        StatusChip.degraded(label: label),
      'lost' || 'revoked' || 'blocked' || 'compromised' =>
        StatusChip.failed(label: label),
      _ => StatusChip.unknown(label: label),
    };
    final trust = device['trust_label']?.toString().trim() ?? '';
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        statusChip,
        if (trust.isNotEmpty)
          StatusChip(
            label: context.tr('Trust {value}', {'value': trust}),
            color: lower == 'suspicious'
                ? AppColors.warning
                : AppColors.accentBlue,
            icon: Icons.shield_outlined,
          ),
      ],
    );
  }

  Widget _activeSessionsChip(
    BuildContext context,
    Map<String, dynamic> device,
  ) {
    final raw = device['active_sessions'];
    final count = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
    return StatusChip.info(
      label: context.tr('{count} active sessions', {'count': count}),
    );
  }

  Widget _deviceActions(BuildContext context, Map<String, dynamic> device) {
    if (_confirming) {
      return IconButton(
        onPressed: null,
        tooltip: context.strings.loading,
        icon: const Icon(Icons.more_vert),
      );
    }
    if (_busy) return portalSpinner(Theme.of(context).colorScheme.primary);
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'details':
            _showDetails(device);
          case 'edit':
            _edit(device);
          case 'trust':
            _trust(device);
          case 'lost':
            _reportLost(device);
          case 'delete':
            _delete(device);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'details',
          child: Text(context.tr('View details')),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Text(context.tr('Rename / notes')),
        ),
        PopupMenuItem<String>(
          value: 'trust',
          child: Text(context.tr('Mark trusted')),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'lost',
          child: Text(context.tr('Report lost')),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(context.tr('Delete device')),
        ),
      ],
    );
  }

  void _showDetails(Map<String, dynamic> device) {
    if (!_hasId(device)) {
      _setActionError('This device record has no usable ID.');
      return;
    }
    DeviceDetailDialog.show(context, api: widget.api, device: device);
  }

  Widget _buildList(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final mobile = constraints.maxWidth < 640;
      final filtered = _filteredDevices();
      final rows = mobile
          ? filtered.take(_mobileVisibleCount).toList(growable: false)
          : filtered
                .skip(_page * _DevicesTabState._pageSize)
                .take(_DevicesTabState._pageSize)
                .toList(growable: false);
      final emptyTitle = _hasActiveFilters
          ? 'No devices match the current filters.'
          : 'No physical devices have been recorded.';
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (_notice != null) MessageBanner(_notice, ok: true),
          if (_actionError != null) MessageBanner(_actionError),
          if (_devices.isNotEmpty && !_confirming) ...[
            _filters(context),
            const SizedBox(height: 12),
          ],
          if (filtered.isEmpty)
            EmptyState(
              compact: true,
              variant: _hasActiveFilters
                  ? EmptyStateVariant.noMatch
                  : EmptyStateVariant.empty,
              icon: Icons.devices_other_outlined,
              title: emptyTitle,
              actionLabel: _hasActiveFilters ? 'Clear filter' : null,
              actionIcon: Icons.filter_alt_off,
              onAction: _hasActiveFilters ? _clearFilters : null,
            )
          else if (!mobile && rows.isEmpty)
            EmptyPageState(onBackToFirst: () => _update(_resetPagination))
          else ...[
            AdminDataTable(
              minWidth: 740,
              density: TableDensity.compact,
              sortColumn: _sortColumn,
              sortAscending: _sortAscending,
              onSort: _onSort,
              columns: _columns(context, rows),
              itemCount: rows.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
              onRowTap: (index) => _showDetails(rows[index]),
            ),
            if (mobile && rows.length < filtered.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _busy || _loading
                      ? null
                      : () => _update(
                          () => _mobileVisibleCount += _DevicesTabState._pageSize,
                        ),
                  icon: const Icon(Icons.expand_more),
                  label: Text(context.tr('Load more')),
                ),
              ),
            if (!mobile &&
                (filtered.length > _DevicesTabState._pageSize || _page > 0))
              PaginationControls(
                page: _page + 1,
                total: filtered.length,
                canGoBack: _page > 0 && !_busy,
                canGoNext:
                    (_page + 1) * _DevicesTabState._pageSize <
                        filtered.length &&
                    !_busy,
                onPrevious: () => _update(() => _page--),
                onNext: () => _update(() => _page++),
              ),
          ],
        ],
      );
    },
  );
}
