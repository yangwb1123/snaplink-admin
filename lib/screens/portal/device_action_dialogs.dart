part of 'devices_tab.dart';

class DeviceMetadataUpdate {
  final String name;
  final String notes;

  const DeviceMetadataUpdate({required this.name, required this.notes});
}

class _DeviceEditDialog extends StatefulWidget {
  final Map<String, dynamic> device;

  const _DeviceEditDialog({required this.device});

  @override
  State<_DeviceEditDialog> createState() => _DeviceEditDialogState();
}

class _DeviceEditDialogState extends State<_DeviceEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.device['device_name']?.toString() ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.device['notes']?.toString() ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(
      DeviceMetadataUpdate(name: _name.text.trim(), notes: _notes.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    // Account for AlertDialog's horizontal content padding. This keeps the
    // form usable on a phone instead of allowing its nominal width to overflow.
    final contentWidth = (size.width - 80).clamp(160.0, 440.0).toDouble();
    final contentHeight = (size.height - viewInsets.vertical - 176)
        .clamp(120.0, 360.0)
        .toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      constraints: BoxConstraints(maxWidth: contentWidth + 48),
      title: Text(
        context.tr('Edit device'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: contentWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: contentHeight),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _name,
                  maxLength: 120,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  decoration: InputDecoration(
                    labelText: context.tr('Device name'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLength: 500,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: context.tr('Private notes'),
                    hintText: context.tr('For example: work laptop'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.strings.save)),
      ],
    );
  }
}

Future<DeviceMetadataUpdate?> showDeviceEditDialog(
  BuildContext context,
  Map<String, dynamic> device,
) => showDialog<DeviceMetadataUpdate>(
  context: context,
  builder: (_) => _DeviceEditDialog(device: device),
);

Future<bool> confirmDeviceAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
  String? confirmText,
}) => ConfirmDialog.show(
  context,
  title: title,
  message: message,
  confirmLabel: confirmLabel,
  destructive: destructive,
  confirmText: confirmText,
);

extension _DeviceFiltering on _DevicesTabState {
  void _resetPagination() {
    _page = 0;
    _mobileVisibleCount = _DevicesTabState._pageSize;
  }

  void _onSearchChanged(String value) => _update(() {
    _searchQuery = value.trim().toLowerCase();
    _resetPagination();
  });

  void _setTypeFilter(String? value) => _update(() {
    _typeFilter = value;
    _resetPagination();
  });

  void _setStatusFilter(String? value) => _update(() {
    _statusFilter = value;
    _resetPagination();
  });

  void _setActivityFilter(String? value) => _update(() {
    _activityFilter = value;
    _resetPagination();
  });

  void _clearFilters() {
    _searchController.clear();
    _update(() {
      _searchQuery = '';
      _typeFilter = _statusFilter = _activityFilter = null;
      _resetPagination();
    });
  }

  void _onSort(String column) => _update(() {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    _resetPagination();
  });

  List<Map<String, dynamic>> _filteredDevices() {
    final rows = _devices.where(_matchesDevice).toList();
    final column = _sortColumn;
    if (column == null) return rows;
    rows.sort((a, b) {
      final result = _sortValue(a, column).compareTo(_sortValue(b, column));
      return _sortAscending ? result : -result;
    });
    return rows;
  }

  bool _matchesDevice(Map<String, dynamic> device) {
    final type = _deviceType(device).toLowerCase();
    final status = _deviceStatus(device).toLowerCase();
    return (_searchQuery.isEmpty ||
            _deviceSearchText(device).contains(_searchQuery)) &&
        (_typeFilter == null || type == _typeFilter!.toLowerCase()) &&
        (_statusFilter == null || status == _statusFilter!.toLowerCase()) &&
        _matchesActivity(device);
  }

  bool _matchesActivity(Map<String, dynamic> device) {
    final filter = _activityFilter;
    if (filter == null) return true;
    final activity = _activityDate(device);
    if (filter == 'Last 24 hours') {
      return _within(activity, const Duration(hours: 24));
    }
    if (filter == 'Last 7 days') {
      return _within(activity, const Duration(days: 7));
    }
    if (activity == null) return true;
    return DateTime.now().toUtc().difference(activity.toUtc()) >
        const Duration(days: 7);
  }

  bool _within(DateTime? value, Duration window) {
    if (value == null) return false;
    final age = DateTime.now().toUtc().difference(value.toUtc());
    return age <= window && age >= const Duration(days: -1);
  }

  String _deviceSearchText(Map<String, dynamic> device) => [
    _deviceName(device),
    _deviceType(device),
    _deviceStatus(device),
    _value(device, const [
      'id',
      'platform',
      'browser_name',
      'last_ip',
      'fingerprint',
      'notes',
      'trust_label',
      'last_seen_at',
      'last_activity_at',
      'last_active_at',
      'recent_activity_at',
    ]),
  ].join(' ').toLowerCase();

  String _sortValue(Map<String, dynamic> device, String column) {
    if (column == 'activity') {
      return (_activityDate(device)?.millisecondsSinceEpoch ?? -1)
          .toString()
          .padLeft(20, '0');
    }
    return switch (column) {
      'type' => _deviceType(device).toLowerCase(),
      'status' => _deviceStatus(device).toLowerCase(),
      _ => _deviceName(device).toLowerCase(),
    };
  }

  List<String> _filterValues(String Function(Map<String, dynamic>) value) {
    final values = <String>{for (final device in _devices) value(device)};
    return values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _typeFilter != null ||
      _statusFilter != null ||
      _activityFilter != null;
}

String _id(Map<String, dynamic> device) => device['id']?.toString() ?? '';

bool _hasId(Map<String, dynamic> device) => _id(device).trim().isNotEmpty;

String _value(Map<String, dynamic> device, List<String> keys) {
  for (final key in keys) {
    final value = device[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _deviceName(Map<String, dynamic> device) {
  final name = device['device_name']?.toString().trim() ?? '';
  if (name.isNotEmpty) return name;
  final platform = device['platform']?.toString().trim() ?? '';
  final type = device['type']?.toString().trim() ?? '';
  return [platform, type].where((part) => part.isNotEmpty).join(' ');
}

String _deviceType(Map<String, dynamic> device) {
  final value = _value(device, const ['type', 'device_type', 'kind']);
  return value.isEmpty ? 'Unknown' : value;
}

String _deviceStatus(Map<String, dynamic> device) {
  final explicit = _value(device, const [
    'status',
    'state',
    'posture_status',
    'device_status',
  ]);
  if (explicit.isNotEmpty) return explicit;
  if (device['lost'] == true || device['reported_lost'] == true) return 'Lost';
  if (device['suspicious'] == true) return 'Suspicious';
  if (device['revoked'] == true) return 'Revoked';
  return 'Active';
}

String _statusLabel(String value) => switch (value.toLowerCase()) {
  'active' => 'Active',
  'online' => 'Online',
  'current' => 'Current',
  'trusted' => 'Trusted',
  'healthy' => 'Healthy',
  'pending' => 'Pending',
  'suspicious' => 'Suspicious',
  'warning' => 'Warning',
  'degraded' => 'Degraded',
  'lost' => 'Lost',
  'revoked' => 'Revoked',
  'blocked' => 'Blocked',
  'compromised' => 'Compromised',
  _ => value.isEmpty ? 'Unknown' : value,
};

String _activityRaw(Map<String, dynamic> device) => _value(device, const [
  'last_activity_at',
  'last_active_at',
  'recent_activity_at',
  'last_seen_at',
  'last_login_at',
  'updated_at',
]);

DateTime? _activityDate(Map<String, dynamic> device) {
  final raw = _activityRaw(device);
  return raw.isEmpty ? null : DateTime.tryParse(raw);
}

String _activityText(BuildContext context, Map<String, dynamic> device) {
  final raw = _activityRaw(device);
  return raw.isEmpty ? context.tr('Unknown') : formatServerTime(raw);
}

IconData _deviceIconData(String type) => switch (type.toLowerCase()) {
  'mobile' || 'phone' => Icons.smartphone,
  'tablet' => Icons.tablet,
  'desktop' || 'laptop' => Icons.desktop_windows,
  'browser' => Icons.language,
  'bot' => Icons.smart_toy_outlined,
  _ => Icons.devices_other,
};
