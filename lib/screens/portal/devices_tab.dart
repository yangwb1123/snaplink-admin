import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'device_detail_dialog.dart';
import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'portal_widgets.dart';

part 'device_action_dialogs.dart';
part 'device_center_widgets.dart';

/// Physical-device center: lists every client Snaplink observed during
/// authentication, with posture trust, sessions, rename/notes, report-lost
/// and delete actions. Desktop uses the shared data table; narrow viewports
/// use its card mode. A trusted-browser grant at `/me/devices` is rejected.
class DevicesTab extends StatefulWidget {
  final PortalApi api;

  const DevicesTab({super.key, required this.api});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _confirming = false;
  bool _requestInFlight = false;
  int _loadSequence = 0;
  List<Map<String, dynamic>> _devices = const [];
  String? _error;
  String? _actionError;
  String? _notice;

  String _searchQuery = '';
  String? _typeFilter;
  String? _statusFilter;
  String? _activityFilter;
  String? _sortColumn;
  bool _sortAscending = true;
  int _page = 0;
  int _mobileVisibleCount = _pageSize;

  static const _pageSize = 20;
  static const _activityFilters = <String>[
    'Last 24 hours',
    'Last 7 days',
    'Older',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) => setState(change);

  Future<void> _load({bool preserveNotice = false}) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    final sequence = ++_loadSequence;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _actionError = null;
        if (!preserveNotice) _notice = null;
        _resetPagination();
      });
    }
    try {
      final response = await widget.api.get(PortalSecurityPaths.devices);
      if (!mounted || sequence != _loadSequence) return;
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
      setState(() => _devices = devices);
    } catch (_) {
      if (mounted && sequence == _loadSequence) {
        setState(() => _error = 'Could not load your devices.');
      }
    } finally {
      _requestInFlight = false;
      if (mounted && sequence == _loadSequence) {
        setState(() => _loading = false);
      }
    }
  }

  void _retry() {
    if (_busy || _requestInFlight) return;
    _load();
  }

  Future<void> _edit(Map<String, dynamic> device) async {
    if (_busy || _confirming) return;
    if (!_hasId(device)) {
      _setActionError('This device record has no usable ID.');
      return;
    }
    setState(() => _confirming = true);
    DeviceMetadataUpdate? update;
    try {
      update = await showDeviceEditDialog(context, device);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
    if (update == null || !mounted) return;
    await _write(
      () => widget.api.patch(PortalSecurityPaths.device(_id(device)), {
        'name': update!.name,
        'notes': update.notes,
      }),
      'Device details updated.',
    );
  }

  Future<void> _trust(Map<String, dynamic> device) async {
    if (_busy || _confirming) return;
    if (!_hasId(device)) {
      _setActionError('This device record has no usable ID.');
      return;
    }
    if (!await _confirmDeviceAction(
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
      () => widget.api.post(PortalSecurityPaths.deviceTrust(_id(device))),
      'Device posture marked trusted.',
    );
  }

  Future<void> _reportLost(Map<String, dynamic> device) async {
    if (_busy || _confirming) return;
    if (!_hasId(device)) {
      _setActionError('This device record has no usable ID.');
      return;
    }
    if (!await _confirmDeviceAction(
      title: 'Report this device lost?',
      message:
          'Snaplink will flag the device as suspicious and request revocation '
          'of associated sessions. This may sign out the current browser; '
          'verify active sessions separately.',
      confirmLabel: 'Report lost',
      confirmText: _id(device),
    )) {
      return;
    }
    await _write(
      () => widget.api.post(PortalSecurityPaths.deviceLost(_id(device))),
      'Device reported lost. Associated session revocation was requested.',
    );
  }

  Future<void> _delete(Map<String, dynamic> device) async {
    if (_busy || _confirming) return;
    if (!_hasId(device)) {
      _setActionError('This device record has no usable ID.');
      return;
    }
    if (!await _confirmDeviceAction(
      title: 'Delete this physical device?',
      message:
          'The physical-device record will be deleted and revocation of bound '
          'sessions will be requested. This action does not mean “revoke an '
          'MFA trusted-device grant”. Verify active sessions separately.',
      confirmLabel: 'Delete device',
      confirmText: _id(device),
    )) {
      return;
    }
    await _write(
      () => widget.api.delete(PortalSecurityPaths.device(_id(device))),
      'Device deleted. Associated session revocation was requested.',
    );
  }

  Future<bool> _confirmDeviceAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = true,
    String? confirmText,
  }) async {
    if (_busy || _confirming) return false;
    setState(() => _confirming = true);
    try {
      return await confirmDeviceAction(
        context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
        confirmText: confirmText,
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _write(
    Future<http.Response> Function() request,
    String success,
  ) async {
    if (_busy || _requestInFlight) return;
    setState(() {
      _busy = true;
      _notice = null;
      _actionError = null;
    });
    try {
      final response = await request();
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _notice = success);
        await _load(preserveNotice: true);
      } else {
        setState(() => _actionError = 'The device action could not be completed.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'The device action could not be completed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setActionError(String message) {
    if (!mounted) return;
    setState(() {
      _actionError = message;
      _notice = null;
    });
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
                onPressed: _loading || _busy || _requestInFlight ? null : _load,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const SkeletonListTile(itemCount: 4)
              : _error != null
              ? PortalErrorCard(message: context.tr(_error!), onRetry: _retry)
              : PullToRefresh(onRefresh: _load, child: _buildList(context)),
        ),
      ],
    );
  }
}
