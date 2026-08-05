import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'device_security_models.dart';

/// Builds a bounded bulk-device revocation request.
///
/// The operator must first select at least one server-supported condition,
/// refresh the current device inventory to see the estimated match count, and
/// then type a count-specific phrase. Returning null means no request may be
/// sent.
class DeviceBulkRevokeDialog extends StatefulWidget {
  final SnaplinkAdminApi api;

  const DeviceBulkRevokeDialog({super.key, required this.api});

  static Future<DeviceBulkRevokeFilter?> show(
    BuildContext context, {
    required SnaplinkAdminApi api,
  }) => showDialog<DeviceBulkRevokeFilter>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DeviceBulkRevokeDialog(api: api),
  );

  @override
  State<DeviceBulkRevokeDialog> createState() => _DeviceBulkRevokeDialogState();
}

class _DeviceBulkRevokeDialogState extends State<DeviceBulkRevokeDialog> {
  final _platformCtrl = TextEditingController();
  String _deviceType = '';
  double? _trustBelow;
  bool _suspiciousOnly = false;
  bool _estimating = false;
  int? _estimatedCount;
  String? _estimatedSignature;
  String? _error;

  DeviceBulkRevokeFilter get _filter => DeviceBulkRevokeFilter(
    trustBelow: _trustBelow,
    suspiciousOnly: _suspiciousOnly,
    platform: _platformCtrl.text,
    deviceType: _deviceType,
  );

  String get _signature =>
      '${_trustBelow ?? ''}|$_suspiciousOnly|${_platformCtrl.text.trim()}|$_deviceType';

  bool get _estimateIsCurrent =>
      _estimatedCount != null && _estimatedSignature == _signature;

  @override
  void dispose() {
    _platformCtrl.dispose();
    super.dispose();
  }

  void _filterChanged() {
    setState(() {
      _estimatedCount = null;
      _estimatedSignature = null;
      _error = null;
    });
  }

  Future<void> _estimate() async {
    final filter = _filter;
    if (!filter.hasCriteria) {
      setState(
        () => _error =
            'Choose at least one condition. An unfiltered revocation is never allowed.',
      );
      return;
    }
    setState(() {
      _estimating = true;
      _error = null;
      _estimatedCount = null;
    });
    try {
      final response = await widget.api.get(
        DeviceSecurityPaths.devices,
        forceRefresh: true,
      );
      final count = filter.matching(deviceListFrom(response)).length;
      if (!mounted) return;
      setState(() {
        _estimatedCount = count;
        _estimatedSignature = _signature;
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _confirm() async {
    final filter = _filter;
    final count = _estimatedCount;
    if (!filter.hasCriteria ||
        !_estimateIsCurrent ||
        count == null ||
        count < 1) {
      setState(
        () => _error =
            'Refresh the estimate with a bounded filter before continuing.',
      );
      return;
    }
    // This call also proves the transport guard still accepts the current
    // filters before the operator is offered a destructive confirmation.
    filter.toRequestBody();
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke $count matching devices?',
      message:
          'This requests deletion of each matching device record and '
          'invalidation of its bound sessions. Verify the inventory after the '
          'request: the estimate may change and the backend does not expose '
          'per-device failures.',
      confirmLabel: 'Revoke devices',
      destructive: true,
      confirmText: filter.confirmationText(count),
    );
    if (confirmed && mounted) Navigator.pop(context, filter);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalizedText('Bulk revoke devices'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const LocalizedText(
              'Define a bounded risk segment. Empty filters are blocked '
              'because the operation can permanently remove every matched '
              'device. Verify devices and sessions after it completes.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<double?>(
                    initialValue: _trustBelow,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Trust score below'.localized,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: LocalizedText('Not filtered'),
                      ),
                      DropdownMenuItem(
                        value: 0.2,
                        child: LocalizedText('0.20'),
                      ),
                      DropdownMenuItem(
                        value: 0.3,
                        child: LocalizedText('0.30'),
                      ),
                      DropdownMenuItem(
                        value: 0.4,
                        child: LocalizedText('0.40'),
                      ),
                      DropdownMenuItem(
                        value: 0.5,
                        child: LocalizedText('0.50'),
                      ),
                      DropdownMenuItem(
                        value: 0.6,
                        child: LocalizedText('0.60'),
                      ),
                      DropdownMenuItem(
                        value: 0.8,
                        child: LocalizedText('0.80'),
                      ),
                    ],
                    onChanged: (value) {
                      _trustBelow = value;
                      _filterChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: _deviceType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Device type'.localized,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '',
                        child: LocalizedText('All types'),
                      ),
                      DropdownMenuItem(
                        value: 'browser',
                        child: LocalizedText('Browser'),
                      ),
                      DropdownMenuItem(
                        value: 'mobile',
                        child: LocalizedText('Mobile'),
                      ),
                      DropdownMenuItem(
                        value: 'app',
                        child: LocalizedText('App'),
                      ),
                      DropdownMenuItem(
                        value: 'desktop',
                        child: LocalizedText('Desktop'),
                      ),
                      DropdownMenuItem(
                        value: 'tablet',
                        child: LocalizedText('Tablet'),
                      ),
                      DropdownMenuItem(
                        value: 'bot',
                        child: LocalizedText('Bot'),
                      ),
                      DropdownMenuItem(
                        value: 'unknown',
                        child: LocalizedText('Unknown'),
                      ),
                    ],
                    onChanged: (value) {
                      _deviceType = value ?? '';
                      _filterChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: _platformCtrl,
                    onChanged: (_) => _filterChanged(),
                    decoration: InputDecoration(
                      labelText: 'Platform (exact)'.localized,
                      hintText: 'Windows, macOS, iOS…'.localized,
                    ),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              value: _suspiciousOnly,
              onChanged: (value) {
                _suspiciousOnly = value ?? false;
                _filterChanged();
              },
              contentPadding: EdgeInsets.zero,
              title: const LocalizedText('Only devices flagged suspicious'),
              subtitle: const LocalizedText(
                'Conditions are combined with AND, matching Snaplink server semantics.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (_estimateIsCurrent)
              Card(
                color: _estimatedCount == 0
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.10),
                child: ListTile(
                  leading: Icon(
                    _estimatedCount == 0
                        ? Icons.verified_outlined
                        : Icons.warning_amber,
                  ),
                  title: LocalizedText('Estimated matches: $_estimatedCount'),
                  subtitle: LocalizedText(
                    _estimatedCount == 0
                        ? 'No devices currently match; revocation is disabled.'
                        : 'A typed confirmation is required before sending the request.',
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _estimating ? null : () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      OutlinedButton.icon(
        onPressed: _estimating ? null : _estimate,
        icon: _estimating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.calculate_outlined),
        label: const LocalizedText('Estimate matches'),
      ),
      FilledButton.icon(
        onPressed: _estimateIsCurrent && (_estimatedCount ?? 0) > 0
            ? _confirm
            : null,
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        icon: const Icon(Icons.phonelink_erase),
        label: const LocalizedText('Continue'),
      ),
    ],
  );
}
