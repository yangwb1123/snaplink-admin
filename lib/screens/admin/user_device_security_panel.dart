import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'device_security_models.dart';
import 'device_security_widgets.dart';

/// Reusable helpdesk view for a user's devices and completed login history.
///
/// Device and history stores are separate optional Snaplink capabilities, so
/// failures are isolated and one resource remains useful when the other is not
/// mounted.
class UserDeviceSecurityPanel extends StatefulWidget {
  final SnaplinkAdminApi api;
  final String userId;

  const UserDeviceSecurityPanel({
    super.key,
    required this.api,
    required this.userId,
  });

  @override
  State<UserDeviceSecurityPanel> createState() =>
      _UserDeviceSecurityPanelState();
}

class _UserDeviceSecurityPanelState extends State<UserDeviceSecurityPanel> {
  List<DeviceJson> _devices = const [];
  List<DeviceJson> _history = const [];
  bool _loading = false;
  bool _mutating = false;
  String? _deviceError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UserDeviceSecurityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<(String, Map<String, dynamic>?, Object?)> _read(
    String key,
    String path,
  ) async {
    try {
      return (key, await widget.api.get(path, forceRefresh: true), null);
    } catch (error) {
      return (key, null, error);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _deviceError = null;
      _historyError = null;
    });
    final results = await Future.wait([
      _read('devices', DeviceSecurityPaths.userDevices(widget.userId)),
      _read('history', DeviceSecurityPaths.userLoginHistory(widget.userId)),
    ]);
    if (!mounted) return;
    setState(() {
      for (final result in results) {
        if (result.$1 == 'devices') {
          if (result.$2 != null) {
            _devices = deviceListFrom(result.$2);
          } else {
            _deviceError = result.$3.toString();
          }
        } else {
          if (result.$2 != null) {
            _history = loginHistoryFrom(result.$2, key: 'login_history');
          } else {
            _historyError = result.$3.toString();
          }
        }
      }
      _loading = false;
    });
  }

  Future<void> _activity(DeviceJson device) =>
      DeviceActivityDialog.show(context, api: widget.api, device: device);

  Future<void> _resetTrust(DeviceJson device) async {
    final id = deviceId(device);
    if (id.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Reset device trust?',
      message:
          'Set this device to Snaplink’s neutral 0.50 trust baseline. The action is recorded in its trust history.',
      confirmLabel: 'Reset trust',
    );
    if (!confirmed) return;
    await _write(
      () => widget.api.post(DeviceSecurityPaths.resetTrust(id)),
      'Device trust reset.',
    );
  }

  Future<void> _revoke(DeviceJson device) async {
    final id = deviceId(device);
    if (id.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke user device?',
      message:
          'The device will be removed and bound-session invalidation will be '
          'requested. Verify active sessions separately. Type the device ID '
          'to continue.',
      confirmLabel: 'Revoke device',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    await _write(
      () =>
          widget.api.delete(DeviceSecurityPaths.userDevice(widget.userId, id)),
      'Device revoked. Bound-session invalidation was requested.',
    );
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() request,
    String message,
  ) async {
    setState(() => _mutating = true);
    try {
      await request();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText(message)));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _deviceError = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Devices and login history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const LocalizedText(
                  'Investigate access context and revoke a compromised endpoint without affecting unrelated devices.',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading || _mutating ? null : _load,
            tooltip: 'Refresh'.localized,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (_loading) ...[
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
      ] else ...[
        if (_deviceError != null) _warning('Device inventory', _deviceError!),
        DeviceListPanel(
          title: 'Registered devices',
          devices: _devices,
          emptyMessage: _deviceError == null
              ? 'This user has no registered devices.'
              : 'The device store may not be configured.',
          actionsEnabled: !_mutating,
          onActivity: _activity,
          onResetTrust: _resetTrust,
          onRevoke: _revoke,
        ),
        const SizedBox(height: 12),
        if (_historyError != null) _warning('Login history', _historyError!),
        LoginHistoryPanel(records: _history),
      ],
    ],
  );

  Widget _warning(String resource, String error) => Card(
    color: Colors.orange.withValues(alpha: 0.08),
    child: ListTile(
      leading: const Icon(Icons.info_outline, color: Colors.orange),
      title: LocalizedText('$resource unavailable'),
      subtitle: LocalizedText(error),
    ),
  );
}
