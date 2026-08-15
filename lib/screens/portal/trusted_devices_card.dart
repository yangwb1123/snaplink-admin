import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

import '../oidc_login/trusted_device_token.dart';
import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'portal_widgets.dart';

/// Lists and revokes the user's MFA-skip device grants without ever exposing
/// their plaintext tokens. Three-state body: skeleton loading, retryable
/// failure ([EmptyState] error variant), EmptyState empty list. A defensive
/// schema check still blocks DELETE when a misconfigured deployment serves
/// physical-device records at /me/trusted-devices.
class TrustedDevicesCard extends StatefulWidget {
  final PortalApi api;

  const TrustedDevicesCard({super.key, required this.api});

  @override
  State<TrustedDevicesCard> createState() => _TrustedDevicesCardState();
}

class _TrustedDevicesCardState extends State<TrustedDevicesCard> {
  bool _loading = true;
  bool _busy = false;
  bool _ok = false;
  bool _error = false;
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
            _error = false;
            _message =
                'The trusted-device endpoint returned an invalid physical-device payload. Grant revocation is disabled.';
          });
        } else {
          setState(() {
            _devices = devices;
            _invalidPayload = false;
            _error = false;
            _message = null;
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _devices = const [];
          _error = false;
          _message = 'Trusted devices are not enabled.';
        });
      } else {
        setState(() {
          _devices = const [];
          _error = true;
          _message = 'Could not load trusted devices.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _devices = const [];
          _error = true;
          _message = 'Could not load trusted devices.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trustCurrentDevice() async {
    final clientId = widget.api.currentClientId;
    if (clientId == null || clientId.isEmpty) {
      setState(() {
        _ok = false;
        _message =
            'This token has no client context. Sign in through the hosted login page before trusting this browser.';
      });
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
          setState(() {
            _ok = false;
            _message = 'The server did not return a device credential.';
          });
          return;
        }
        TrustedDeviceToken.store(clientId, token);
        setState(() {
          _ok = true;
          _message = 'This browser is trusted until the grant expires.';
        });
        await _load();
      } else if (response.statusCode == 403) {
        setState(() {
          _ok = false;
          _message =
              'Complete MFA in this session before trusting a device.';
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _ok = false;
          _message = 'Trusted devices are not enabled.';
        });
      } else {
        setState(() {
          _ok = false;
          _message = 'Could not trust this device.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ok = false;
          _message = 'Could not trust this device.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> device) async {
    if (_invalidPayload || !isTrustedDeviceGrant(device)) {
      setState(() {
        _ok = false;
        _message =
            'Blocked: this record is not an MFA trusted-browser grant.';
      });
      return;
    }
    final id = device['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }
    final label = device['label']?.toString() ?? id;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke trusted device?',
      message: context.tr('{label} will need to complete MFA again.', {
        'label': label,
      }),
      confirmLabel: 'Revoke',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
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
        setState(() {
          _ok = false;
          _message = 'Could not revoke this trusted device.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ok = false;
          _message = 'Could not revoke this trusted device.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final hasClient = !(widget.api.currentClientId?.isEmpty ?? true);
    return PortalCard(
      title: 'Trusted devices',
      children: [
        Text(
          context.tr(
            'Trusted browsers can skip a future MFA prompt when policy allows it.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy || !hasClient ? null : _trustCurrentDevice,
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(context.tr('Trust this browser')),
        ),
        if (!hasClient)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr(
                'Sign in through the hosted login page before creating a trusted-browser credential.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        MessageBanner(_message, ok: _ok),
        if (_invalidPayload)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr(
                'This response does not match the trusted-device schema. No DELETE request will be issued from this card.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        if (_loading)
          const SkeletonListTile(itemCount: 2)
        else if (_devices.isNotEmpty)
          for (final device in _devices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.devices_outlined, size: 18, color: accent),
              ),
              title: Text(
                device['label']?.toString() ?? device['id']?.toString() ?? '',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${device['client_id'] ?? ''}${device['expires_at'] == null ? '' : context.tr(' · expires {time}', {'time': device['expires_at']})}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: TextButton(
                onPressed: _busy ? null : () => _revoke(device),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(context.tr('Revoke')),
              ),
            )
        else if (_error)
          EmptyState(
            compact: true,
            variant: EmptyStateVariant.error,
            icon: Icons.cloud_off_outlined,
            title: _message ?? 'Could not load trusted devices.',
            actionLabel: 'Retry',
            actionIcon: Icons.refresh,
            onAction: _load,
          )
        else if (_message == null)
          const EmptyState(
            compact: true,
            icon: Icons.devices_other_outlined,
            title: 'No trusted devices.',
          ),
      ],
    );
  }
}
