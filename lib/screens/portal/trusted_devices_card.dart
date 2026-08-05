import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import '../oidc_login/trusted_device_token.dart';
import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'portal_widgets.dart';

/// Lists and revokes the user's MFA-skip device grants without ever exposing
/// their plaintext tokens.
class TrustedDevicesCard extends StatefulWidget {
  final PortalApi api;

  const TrustedDevicesCard({super.key, required this.api});

  @override
  State<TrustedDevicesCard> createState() => _TrustedDevicesCardState();
}

class _TrustedDevicesCardState extends State<TrustedDevicesCard> {
  bool _loading = true;
  bool _busy = false;
  List<Map<String, dynamic>> _devices = const [];
  String? _message;
  bool _invalidPayload = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await widget.api.get(PortalSecurityPaths.trustedDevices);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final devices = portalObjectList(PortalApi.decode(response), 'devices');
        final kind = classifyDeviceCollection(devices);
        if (kind == PortalDeviceCollectionKind.physical ||
            kind == PortalDeviceCollectionKind.ambiguous) {
          setState(() {
            _devices = const [];
            _invalidPayload = true;
            _message =
                'The trusted-device endpoint returned an invalid physical-device payload. Grant revocation is disabled.';
          });
        } else {
          setState(() {
            _devices = devices;
            _invalidPayload = false;
            _message = null;
          });
        }
      } else if (response.statusCode == 404) {
        setState(() => _message = 'Trusted devices are not enabled.');
      } else {
        setState(() => _message = 'Could not load trusted devices.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not load trusted devices.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trustCurrentDevice() async {
    final clientId = widget.api.currentClientId;
    if (clientId == null || clientId.isEmpty) {
      setState(
        () => _message =
            'This token has no client context. Sign in through the hosted login page before trusting this browser.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await widget.api.post(
        PortalSecurityPaths.trustCurrentBrowser,
      );
      if (!mounted) return;
      if (response.statusCode == 201) {
        final token = PortalApi.decode(response)['device_token']?.toString();
        if (token == null || token.isEmpty) {
          setState(
            () => _message = 'The server did not return a device credential.',
          );
          return;
        }
        TrustedDeviceToken.store(clientId, token);
        setState(
          () => _message = 'This browser is trusted until the grant expires.',
        );
        await _load();
      } else if (response.statusCode == 403) {
        setState(
          () => _message =
              'Complete MFA in this session before trusting a device.',
        );
      } else if (response.statusCode == 404) {
        setState(() => _message = 'Trusted devices are not enabled.');
      } else {
        setState(() => _message = 'Could not trust this device.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not trust this device.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> device) async {
    if (_invalidPayload || !isTrustedDeviceGrant(device)) {
      setState(
        () => _message =
            'Blocked: this record is not an MFA trusted-browser grant.',
      );
      return;
    }
    final id = device['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }
    final label = device['label']?.toString() ?? id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Revoke trusted device?')),
        content: Text(
          context.tr('{label} will need to complete MFA again.', {
            'label': label,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('Revoke')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final response = await widget.api.delete(
        PortalSecurityPaths.trustedDevice(id),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final clientId = device['client_id']?.toString();
        if (clientId != null) {
          TrustedDeviceToken.clear(clientId);
        }
        await _load();
      } else if (mounted) {
        setState(() => _message = 'Could not revoke this trusted device.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not revoke this trusted device.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PortalCard(
    title: 'Trusted devices',
    children: [
      Text(
        context.tr(
          'Trusted browsers can skip a future MFA prompt when policy allows it.',
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _busy || (widget.api.currentClientId?.isEmpty ?? true)
            ? null
            : _trustCurrentDevice,
        child: Text(context.tr('Trust this browser')),
      ),
      if (widget.api.currentClientId?.isEmpty ?? true)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            context.tr(
              'Sign in through the hosted login page before creating a trusted-browser credential.',
            ),
          ),
        ),
      MessageBanner(
        _message,
        ok: _message?.startsWith('This browser') ?? false,
      ),
      if (_invalidPayload)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            context.tr(
              'This response does not match the trusted-device schema. No DELETE request will be issued from this card.',
            ),
          ),
        ),
      if (_loading)
        const LinearProgressIndicator()
      else if (_devices.isEmpty)
        const EmptyHint('No trusted devices.')
      else
        for (final device in _devices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              device['label']?.toString() ?? device['id']?.toString() ?? '',
            ),
            subtitle: Text(
              '${device['client_id'] ?? ''}${device['expires_at'] == null ? '' : context.tr(' · expires {time}', {'time': device['expires_at']})}',
            ),
            trailing: TextButton(
              onPressed: _busy ? null : () => _revoke(device),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: Text(context.tr('Revoke')),
            ),
          ),
    ],
  );
}
