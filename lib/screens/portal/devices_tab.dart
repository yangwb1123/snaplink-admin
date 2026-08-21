import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/staggered_fade_in.dart';

import 'device_action_dialogs.dart';
import 'device_center_widgets.dart';
import 'device_detail_dialog.dart';
import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'portal_widgets.dart';

/// Physical-device center: lists every client Snaplink observed during
/// authentication, with posture trust, sessions, rename/notes, report-lost
/// and delete actions. Ports app.js's devices render + device action flows.
///
/// The page intentionally refuses to act on MFA trusted-browser grants that
/// a misconfigured deployment exposes at /me/devices (defensive schema
/// classification, see [classifyDeviceCollection]) — posture actions would
/// otherwise mutate the wrong security data.
///
/// Layout: header → banner → three-state body. Loading renders
/// SkeletonListTile, failures render a retryable [PortalErrorCard], and an
/// empty list renders EmptyState (UI review X3/X4/X8).
class DevicesTab extends StatefulWidget {
  final PortalApi api;

  const DevicesTab({super.key, required this.api});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  bool _loading = true;
  bool _busy = false;
  List<Map<String, dynamic>> _devices = const [];
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool preserveNotice = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!preserveNotice) _notice = null;
    });
    try {
      final response = await widget.api.get(PortalSecurityPaths.devices);
      if (!mounted) return;
      if (response.statusCode == 404 || response.statusCode == 501) {
        setState(() {
          _devices = const [];
          _error = 'Physical-device tracking is not enabled.';
        });
        return;
      }
      if (response.statusCode != 200) {
        setState(() => _error = 'Could not load your devices.');
        return;
      }
      final devices = portalObjectList(PortalApi.decode(response), 'devices');
      final kind = classifyDeviceCollection(devices);
      if (kind == PortalDeviceCollectionKind.trustedGrants ||
          kind == PortalDeviceCollectionKind.ambiguous) {
        setState(() {
          _devices = const [];
          _error =
              'This deployment exposes MFA trusted-browser grants at '
              '/me/devices instead of physical-device records. Device posture '
              'actions are disabled to avoid changing the wrong security data.';
        });
        return;
      }
      setState(() {
        _devices = devices;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your devices.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> device) async {
    final id = _id(device);
    if (id.isEmpty) {
      setState(() => _error = 'This device record has no usable ID.');
      return;
    }
    final update = await showDeviceEditDialog(context, device);
    if (update == null || !mounted) return;
    await _write(
      () => widget.api.patch(PortalSecurityPaths.device(id), {
        'name': update.name,
        'notes': update.notes,
      }),
      'Device details updated.',
    );
  }

  Future<void> _trust(Map<String, dynamic> device) async {
    final id = _id(device);
    if (id.isEmpty) {
      setState(() => _error = 'This device record has no usable ID.');
      return;
    }
    if (!await confirmDeviceAction(
      context,
      title: 'Mark this physical device trusted?',
      message:
          'Snaplink will raise the device posture score to 0.90. This can '
          'affect future risk and conditional-access decisions. It does not '
          'create an MFA-skip browser credential.',
      confirmLabel: 'Mark trusted',
      destructive: false,
    )) {
      return;
    }
    await _write(
      () => widget.api.post(PortalSecurityPaths.deviceTrust(id)),
      'Device posture marked trusted.',
    );
  }

  Future<void> _reportLost(Map<String, dynamic> device) async {
    final id = _id(device);
    if (id.isEmpty) {
      setState(() => _error = 'This device record has no usable ID.');
      return;
    }
    if (!await confirmDeviceAction(
      context,
      title: 'Report this device lost?',
      message:
          'Snaplink will flag the device as suspicious and request revocation '
          'of associated sessions. This may sign out the current browser; '
          'verify active sessions separately.',
      confirmLabel: 'Report lost',
      confirmText: id,
    )) {
      return;
    }
    await _write(
      () => widget.api.post(PortalSecurityPaths.deviceLost(id)),
      'Device reported lost. Associated session revocation was requested.',
    );
  }

  Future<void> _delete(Map<String, dynamic> device) async {
    final id = _id(device);
    if (id.isEmpty) {
      setState(() => _error = 'This device record has no usable ID.');
      return;
    }
    if (!await confirmDeviceAction(
      context,
      title: 'Delete this physical device?',
      message:
          'The physical-device record will be deleted and revocation of bound '
          'sessions will be requested. This action does not mean “revoke an '
          'MFA trusted-device grant”. Verify active sessions separately.',
      confirmLabel: 'Delete device',
      confirmText: id,
    )) {
      return;
    }
    await _write(
      () => widget.api.delete(PortalSecurityPaths.device(id)),
      'Device deleted. Associated session revocation was requested.',
    );
  }

  Future<void> _write(
    Future<http.Response> Function() request,
    String success,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
      _error = null;
    });
    try {
      final response = await request();
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _notice = success);
        await _load(preserveNotice: true);
      } else {
        setState(() => _error = 'The device action could not be completed.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The device action could not be completed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        context.strings.devices,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Physical clients Snaplink has observed during '
                        'authentication.',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Refresh devices'),
                onPressed: _loading || _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const SkeletonListTile(itemCount: 4)
              : _error != null
              ? PortalErrorCard(message: context.tr(_error!), onRetry: _load)
              : PullToRefresh(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: 1 + (_devices.isEmpty ? 1 : _devices.length),
                    itemBuilder: (context, index) {
                      // 首行横幅（或空态）；设备卡按需构建（懒列表，R47）。
                      if (index == 0) {
                        return MessageBanner(_notice, ok: true);
                      }
                      if (_devices.isEmpty) {
                        return const EmptyState(
                          compact: true,
                          icon: Icons.devices_other_outlined,
                          title: 'No physical devices have been recorded.',
                        );
                      }
                      final device = _devices[index - 1];
                      return StaggeredFadeIn(
                        index: index - 1,
                        child: PhysicalDeviceCard(
                          device: device,
                          busy: _busy,
                          onDetails: (value) => DeviceDetailDialog.show(
                            context,
                            api: widget.api,
                            device: value,
                          ),
                          onEdit: _edit,
                          onTrust: _trust,
                          onLost: _reportLost,
                          onDelete: _delete,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

String _id(Map<String, dynamic> device) => device['id']?.toString() ?? '';
