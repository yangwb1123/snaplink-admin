import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/format_helpers.dart';

import 'device_bulk_revoke_dialog.dart';
import 'device_security_activity_dialog.dart';
import 'device_security_dashboard_widgets.dart';
import 'device_security_models.dart';
import 'device_security_widgets.dart';

/// 写入操作的本地化反馈：(i18n key, placeholder args)。
typedef _WriteMessage = (String, Map<String, Object?>)
    Function(Map<String, dynamic> result);

/// Fleet-level device risk and response workspace.
///
/// Snaplink mounts these routes only when a device store is configured. The
/// screen therefore treats each read independently and preserves useful data
/// if one optional source is unavailable.
class DeviceSecurityTab extends StatefulWidget {
  final SnaplinkAdminApi api;

  const DeviceSecurityTab({super.key, required this.api});

  @override
  State<DeviceSecurityTab> createState() => _DeviceSecurityTabState();
}

class _DeviceSecurityTabState extends State<DeviceSecurityTab> {
  final _userCtrl = TextEditingController();
  final _platformCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  List<DeviceJson> _devices = const [];
  List<DeviceJson> _securityEvents = const [];
  Map<String, dynamic> _stats = const {};
  String _deviceType = '';
  String _trustLevel = '';
  bool _suspiciousOnly = false;
  bool _loading = false;
  bool _mutating = false;
  int _fleetTotal = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _platformCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _query => {
    if (_userCtrl.text.trim().isNotEmpty) 'user_id': _userCtrl.text.trim(),
    if (_platformCtrl.text.trim().isNotEmpty)
      'platform': _platformCtrl.text.trim(),
    if (_ipCtrl.text.trim().isNotEmpty) 'last_ip': _ipCtrl.text.trim(),
    if (_deviceType.isNotEmpty) 'type': _deviceType,
    if (_trustLevel.isNotEmpty) 'trust_level': _trustLevel,
    if (_suspiciousOnly) 'suspicious': 'true',
  };

  Future<(String, Map<String, dynamic>?, Object?)> _read(
    String key,
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final value = query == null || query.isEmpty
          ? await widget.api.getStaleWhileRevalidate(
              path,
              onRefresh: (fresh) {
                if (mounted) setState(() => _applyResult(key, fresh));
              },
            )
          : await widget.api.get(path, query: query);
      return (key, value, null);
    } catch (error) {
      return (key, null, error);
    }
  }

  /// 缓存先渲染：命中时立即展示缓存行，后台刷新到位后原位更新（R2）。
  void _applyResult(String key, Map<String, dynamic> data) {
    switch (key) {
      case 'devices':
        _devices = deviceListFrom(data);
        _fleetTotal = (data['total'] as num?)?.toInt() ?? _devices.length;
      case 'stats':
        _stats = data;
      case 'events':
        _securityEvents = loginHistoryFrom(data, key: 'events');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      _read('devices', DeviceSecurityPaths.devices, query: _query),
      _read('stats', DeviceSecurityPaths.stats),
      _read('events', DeviceSecurityPaths.securityActivity),
    ]);
    if (!mounted) return;
    final failures = <String>[];
    setState(() {
      for (final result in results) {
        final data = result.$2;
        if (data == null) {
          failures.add('${result.$1}: ${result.$3}');
          continue;
        }
        _applyResult(result.$1, data);
      }
      _error = failures.isEmpty
          ? null
          : context.tr(
              'Some device data is unavailable — {failures}',
              {'failures': failures.join(' · ')},
            );
      _loading = false;
    });
  }

  void _clearFilters() {
    _userCtrl.clear();
    _platformCtrl.clear();
    _ipCtrl.clear();
    setState(() {
      _deviceType = '';
      _trustLevel = '';
      _suspiciousOnly = false;
    });
    _load();
  }

  Future<void> _showActivity(DeviceJson device) =>
      DeviceActivityDialog.show(context, api: widget.api, device: device);

  Future<void> _resetTrust(DeviceJson device) async {
    final id = deviceId(device);
    if (id.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Reset device trust?',
      message:
          'Snaplink will set this device to the neutral 0.50 trust baseline '
          'and record an admin-reset history entry.',
      confirmLabel: 'Reset trust',
    );
    if (!confirmed) return;
    await _write(
      () => widget.api.post(DeviceSecurityPaths.resetTrust(id)),
      (result) => (
        'Trust reset to {score} ({label}).',
        {
          'score': result['trust_score'] ?? '0.5',
          'label': result['trust_label'] ?? 'Medium',
        },
      ),
    );
  }

  Future<void> _revoke(DeviceJson device) async {
    final id = deviceId(device);
    final userId = device['user_id']?.toString() ?? '';
    if (id.isEmpty || userId.isEmpty) {
      setState(() => _error = 'The selected device has no user/device ID.');
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke this device?',
      message:
          'The device record will be deleted and bound-session invalidation '
          'will be requested. Verify active sessions separately. Type the '
          'device ID to continue.',
      confirmLabel: 'Revoke device',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    await _write(
      () => widget.api.delete(DeviceSecurityPaths.userDevice(userId, id)),
      (_) => (
        'Device revoked. Bound-session invalidation was requested.',
        const <String, Object?>{},
      ),
    );
  }

  Future<void> _bulkRevoke() async {
    final filter = await DeviceBulkRevokeDialog.show(context, api: widget.api);
    if (filter == null) return;
    if (!filter.hasCriteria) {
      setState(
        () => _error =
            'Safety boundary blocked an unfiltered bulk device revocation.',
      );
      return;
    }
    late final Map<String, dynamic> body;
    try {
      body = filter.toRequestBody();
    } on StateError catch (error) {
      setState(() => _error = error.message);
      return;
    }
    await _write(
      () => widget.api.post(DeviceSecurityPaths.bulkRevoke, body),
      (result) => (
        'Bulk revocation request accepted. The server reported {revoked} '
            'revoked of {matched} matched; verify device inventory before '
            'treating the segment as fully revoked.',
        {'revoked': result['revoked'] ?? 0, 'matched': result['matched'] ?? 0},
      ),
    );
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() request,
    _WriteMessage message,
  ) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final result = await request();
      if (!mounted) return;
      final (key, args) = message(result);
      showAppSnackBar(context, content: LocalizedText(key, args: args));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      AdminListHeader(
        title: 'Device security',
        subtitle:
            'Fleet posture, device-level investigation, and bounded incident '
            'response.',
        onRefresh: () {
          if (!_loading && !_mutating) _load();
        },
        actions: [
          FilledButton.icon(
            onPressed: _loading || _mutating ? null : _bulkRevoke,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            icon: const Icon(Icons.phonelink_erase),
            label: const LocalizedText('Bulk revoke'),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _loading || _mutating ? null : _load,
            tooltip: 'Refresh'.localized,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      DeviceStatsCards(stats: _stats, fleetTotal: _fleetTotal),
      const SizedBox(height: 12),
      DeviceFleetFilters(
        userController: _userCtrl,
        platformController: _platformCtrl,
        ipController: _ipCtrl,
        deviceType: _deviceType,
        trustLevel: _trustLevel,
        suspiciousOnly: _suspiciousOnly,
        loading: _loading,
        onDeviceTypeChanged: (value) => setState(() => _deviceType = value),
        onTrustLevelChanged: (value) => setState(() => _trustLevel = value),
        onSuspiciousChanged: (value) => setState(() => _suspiciousOnly = value),
        onApply: _load,
        onClear: _clearFilters,
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        ErrorStateCard(message: _error!, onRetry: _loading ? null : _load, margin: EdgeInsets.zero),
      ],
      if (_loading) ...[
        const SizedBox(height: 12),
        const SkeletonListTile(itemCount: 3),
      ] else ...[
        const SizedBox(height: 12),
        DeviceListPanel(
          title: _query.isEmpty
              ? 'All devices ({total} total)'
              : 'Filtered devices ({shown} of {total})',
          titleArgs: _query.isEmpty
              ? {'total': formatCount(_fleetTotal)}
              : {'shown': formatCount(_devices.length), 'total': formatCount(_fleetTotal)},
          devices: _devices,
          actionsEnabled: !_mutating,
          onActivity: _showActivity,
          onResetTrust: _resetTrust,
          onRevoke: _revoke,
        ),
        const SizedBox(height: 12),
        DeviceSecurityActivityPanel(
          events: _securityEvents,
          onInvestigate: _showActivity,
        ),
      ],
    ],
  );
}

