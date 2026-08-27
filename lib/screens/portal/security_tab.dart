import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';

import 'passkey_enrollment_card.dart';
import 'security_account_credentials.dart';
import 'security_mfa_card.dart';
import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'recovery_codes_card.dart';
import 'trusted_devices_card.dart';

/// "Change email" cards from index.html / the loadMFA / totp / pw / email
/// handlers in app.js. MFA factor list and TOTP enrollment live here; the
/// other security surfaces (passkeys, recovery codes, trusted devices,
/// password/email credentials) are self-contained cards below.
class SecurityTab extends StatefulWidget {
  final PortalApi api;
  const SecurityTab({super.key, required this.api});
  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  // --- MFA factor list ---
  bool _mfaLoading = true;
  bool _mfaBusy = false;
  bool _mfaRequestInFlight = false;
  bool _factorConfirming = false;
  bool _mfaError = false;
  bool _mfaNotEnabled = false;
  bool _mfaOk = false;
  List<dynamic> _factors = const [];
  String? _mfaEmptyHint; // e.g. "Factor management is not enabled."
  String? _mfaMessage;
  // --- TOTP enrollment (begin -> confirm) ---
  bool _totpPanelOpen = false;
  String _pendingSecret = '';
  String _pendingUri = '';
  final TextEditingController _totpLabelCtrl = TextEditingController();
  final TextEditingController _totpCodeCtrl = TextEditingController();
  String? _totpMsg;
  bool _totpBusy = false;
  @override
  void initState() {
    super.initState();
    _loadMfa();
  }

  @override
  void dispose() {
    _pendingSecret = '';
    _pendingUri = '';
    _totpCodeCtrl.clear();
    _totpLabelCtrl.dispose();
    _totpCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMfa() async {
    if (_mfaRequestInFlight) return;
    _mfaRequestInFlight = true;
    if (mounted) {
      setState(() {
        _mfaLoading = true;
        _mfaError = false;
        _mfaNotEnabled = false;
        _mfaEmptyHint = null;
      });
    }
    try {
      final r = await widget.api.get(PortalPaths.mfa);
      if (!mounted) return;
      if (r.statusCode == 404) {
        setState(() {
          _factors = const [];
          _mfaEmptyHint = 'Factor management is not enabled.';
          _mfaNotEnabled = true;
        });
        return;
      }
      if (r.statusCode != 200) {
        setState(() {
          _factors = const [];
          _mfaEmptyHint = 'Could not load your second factors.';
          _mfaError = true;
        });
        return;
      }
      final d = PortalApi.decode(r);
      final list = ((d['factors'] as List?) ?? const [])
          .whereType<Map>()
          .map((factor) {
            final normalized = Map<String, dynamic>.from(factor);
            if (!normalized.containsKey('method') &&
                normalized['type'] != null) {
              normalized['method'] = normalized['type'];
            }
            return normalized;
          })
          .toList(growable: false);
      setState(() {
        _factors = list;
        _mfaEmptyHint = list.isEmpty ? 'No second factors registered.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _factors = const [];
        _mfaEmptyHint = 'Could not load your second factors.';
        _mfaError = true;
      });
    } finally {
      _mfaRequestInFlight = false;
      if (mounted) setState(() => _mfaLoading = false);
    }
  }

  Future<void> _removeFactor(String id) async {
    if (id.isEmpty || _mfaBusy || _totpBusy || _factorConfirming) return;
    setState(() => _factorConfirming = true);
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove second factor?',
      message:
          'You may lose access if this is your only sign-in backup. You can add another factor afterward.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (mounted) setState(() => _factorConfirming = false);
    if (!confirmed || !mounted || _mfaBusy || _totpBusy) return;
    setState(() {
      _mfaBusy = true;
      _mfaMessage = null;
      _mfaOk = false;
    });
    try {
      final response = await widget.api.delete(PortalPaths.mfaFactor(id));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (mounted) {
          setState(() => _mfaMessage = 'Could not remove this second factor.');
        }
        return;
      }
      await _loadMfa();
      if (mounted) {
        setState(() {
          _mfaMessage = 'Second factor removed.';
          _mfaOk = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _mfaMessage = 'Could not remove this second factor.');
      }
    } finally {
      if (mounted) setState(() => _mfaBusy = false);
    }
  }

  Future<void> _beginTotp() async {
    if (_totpBusy || _mfaBusy || _mfaRequestInFlight) return;
    setState(() {
      _totpMsg = null;
      _totpPanelOpen = true;
      _totpBusy = true;
      _pendingSecret = '';
      _pendingUri = '';
      _totpCodeCtrl.clear();
    });
    try {
      final r = await widget.api.post(PortalPaths.totpBegin);
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = PortalApi.decode(r);
        final secret = d['secret']?.toString() ?? '';
        if (secret.isEmpty) {
          setState(() => _totpMsg = 'Could not start TOTP enrollment.');
        } else {
          setState(() {
            _pendingSecret = secret;
            _pendingUri = d['otpauth_uri']?.toString() ?? '';
          });
        }
      } else {
        setState(
          () => _totpMsg = r.statusCode == 404
              ? 'TOTP enrollment is not enabled.'
              : 'Could not start TOTP enrollment.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _totpMsg = 'Could not start TOTP enrollment.');
      }
    } finally {
      if (mounted) setState(() => _totpBusy = false);
    }
  }

  void _cancelTotp() {
    setState(() {
      _totpPanelOpen = false;
      _pendingSecret = '';
      _pendingUri = '';
      _totpCodeCtrl.clear();
      _totpLabelCtrl.clear();
      _totpMsg = null;
    });
  }

  Future<void> _confirmTotp() async {
    if (_totpBusy) return;
    final code = _totpCodeCtrl.text.trim();
    if (_pendingSecret.isEmpty || code.isEmpty) {
      setState(() => _totpMsg = 'Enter the 6-digit code.');
      return;
    }
    setState(() => _totpBusy = true);
    try {
      final r = await widget.api.post(PortalPaths.totpConfirm, {
        'secret': _pendingSecret,
        'code': code,
        'label': _totpLabelCtrl.text,
      });
      if (r.statusCode == 201) {
        setState(() {
          _totpPanelOpen = false;
          _pendingSecret = '';
          _pendingUri = '';
          _totpCodeCtrl.clear();
          _totpLabelCtrl.clear();
          _totpMsg = null;
        });
        await _loadMfa();
        return;
      }
      if (mounted) {
        setState(
          () => _totpMsg = r.statusCode == 404
              ? 'TOTP enrollment is not enabled.'
              : r.statusCode == 400
              ? 'That code was not accepted. Check your device clock and try again.'
              : 'Could not confirm TOTP enrollment.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _totpMsg = 'Could not confirm TOTP enrollment.');
      }
    } finally {
      if (mounted) setState(() => _totpBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PullToRefresh(
      onRefresh: _refreshMfa,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              context.strings.security,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LocalizedText(
                  'Multi-factor authentication and the security factors on your account.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('Retry'),
                onPressed:
                    _mfaLoading || _mfaBusy || _totpBusy || _factorConfirming
                    ? null
                    : _loadMfa,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SecurityMfaCard(
            mfaLoading: _mfaLoading,
            mfaError: _mfaError,
            mfaNotEnabled: _mfaNotEnabled,
            factors: _factors,
            mfaEmptyHint: _mfaEmptyHint,
            mfaMessage: _mfaMessage,
            mfaOk: _mfaOk,
            mfaBusy: _mfaBusy || _totpBusy || _mfaLoading || _factorConfirming,
            totpPanelOpen: _totpPanelOpen,
            totpBusy: _totpBusy,
            totpMsg: _totpMsg,
            pendingSecret: _pendingSecret,
            pendingUri: _pendingUri,
            totpLabelCtrl: _totpLabelCtrl,
            totpCodeCtrl: _totpCodeCtrl,
            onBeginTotp: _beginTotp,
            onConfirmTotp: _confirmTotp,
            onCancelTotp: _cancelTotp,
            onRetry: _loadMfa,
            onRemoveFactor: (id) => _removeFactor(id),
          ),
          PasskeyEnrollmentCard(api: widget.api, onEnrolled: _loadMfa),
          RecoveryCodesCard(api: widget.api),
          TrustedDevicesCard(api: widget.api),
          SecurityAccountCredentials(api: widget.api),
        ],
      ),
    );
  }

  Future<void> _refreshMfa() async {
    if (_mfaBusy || _totpBusy || _factorConfirming) return;
    await _loadMfa();
  }
}
