import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'passkey_enrollment_card.dart';
import 'security_account_credentials.dart';
import 'security_mfa_card.dart';
import 'portal_api.dart';
import 'recovery_codes_card.dart';
import 'trusted_devices_card.dart';

/// "Change email" cards from index.html / the loadMFA / totp / pw / email
/// handlers in app.js.
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
    setState(() {
      _mfaLoading = true;
      _mfaEmptyHint = null;
    });
    try {
      final r = await widget.api.get('/me/mfa');
      if (!mounted) return;
      if (r.statusCode == 404) {
        setState(() {
          _factors = const [];
          _mfaEmptyHint = 'Factor management is not enabled.';
          _mfaLoading = false;
        });
        return;
      }
      if (r.statusCode != 200) {
        setState(() {
          _factors = const [];
          _mfaEmptyHint = 'Could not load your second factors.';
          _mfaLoading = false;
        });
        return;
      }
      final d = PortalApi.decode(r);
      final list = (d['factors'] as List?) ?? const [];
      setState(() {
        _factors = list;
        _mfaEmptyHint = list.isEmpty ? 'No second factors registered.' : null;
        _mfaLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _factors = const [];
        _mfaEmptyHint = 'Could not load your second factors.';
        _mfaLoading = false;
      });
    }
  }

  Future<void> _removeFactor(String id) async {
    if (id.isEmpty || _mfaBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove second factor?')),
        content: Text(
          context.tr(
            'You may lose access if this is your only sign-in backup. You can add another factor afterward.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _mfaBusy = true;
      _mfaMessage = null;
    });
    try {
      final response = await widget.api.delete(
        '/me/mfa/${Uri.encodeComponent(id)}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (mounted) {
          setState(() => _mfaMessage = 'Could not remove this second factor.');
        }
        return;
      }
      await _loadMfa();
      if (mounted) {
        setState(() => _mfaMessage = 'Second factor removed.');
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
    setState(() {
      _totpMsg = null;
      _totpPanelOpen = true;
      _totpBusy = true;
      _pendingSecret = '';
      _pendingUri = '';
      _totpCodeCtrl.clear();
    });
    try {
      final r = await widget.api.post('/me/mfa/totp/begin');
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
    final code = _totpCodeCtrl.text.trim();
    if (_pendingSecret.isEmpty || code.isEmpty) {
      setState(() => _totpMsg = 'Enter the 6-digit code.');
      return;
    }
    setState(() => _totpBusy = true);
    try {
      final r = await widget.api.post('/me/mfa/totp/confirm', {
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.strings.security,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        SecurityMfaCard(
          mfaLoading: _mfaLoading,
          factors: _factors,
          mfaEmptyHint: _mfaEmptyHint,
          mfaMessage: _mfaMessage,
          mfaBusy: _mfaBusy,
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
          onRemoveFactor: (id) => _removeFactor(id),
        ),
        PasskeyEnrollmentCard(api: widget.api, onEnrolled: _loadMfa),
        RecoveryCodesCard(api: widget.api),
        TrustedDevicesCard(api: widget.api),
        SecurityAccountCredentials(api: widget.api),
      ],
    );
  }
}
