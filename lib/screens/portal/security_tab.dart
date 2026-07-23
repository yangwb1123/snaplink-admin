import 'package:flutter/material.dart';
import 'passkey_enrollment_card.dart';
import 'portal_api.dart';
import 'portal_widgets.dart';
import 'recovery_codes_card.dart';
import 'trusted_devices_card.dart';

/// Two-factor methods (list/remove + TOTP enrollment) + change password +
/// change email. Ports the "Two-factor methods", "Change password" and
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

  // --- Password change ---
  final TextEditingController _curPwCtrl = TextEditingController();
  final TextEditingController _newPwCtrl = TextEditingController();
  String? _pwMsg;
  bool _pwOk = false;
  bool _pwBusy = false;

  // --- Email change (begin -> verify) ---
  final TextEditingController _newEmailCtrl = TextEditingController();
  final TextEditingController _emailTokenCtrl = TextEditingController();
  bool _emailVerifyVisible = false;
  String? _emailMsg;
  bool _emailOk = false;
  bool _emailBusy = false;

  @override
  void initState() {
    super.initState();
    _loadMfa();
  }

  @override
  void dispose() {
    _totpLabelCtrl.dispose();
    _totpCodeCtrl.dispose();
    _curPwCtrl.dispose();
    _newPwCtrl.dispose();
    _newEmailCtrl.dispose();
    _emailTokenCtrl.dispose();
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
        title: const Text('Remove second factor?'),
        content: const Text(
          'You may lose access if this is your only sign-in backup. You can add another factor afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
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

  Future<void> _changePassword() async {
    final cur = _curPwCtrl.text, next = _newPwCtrl.text;
    if (cur.isEmpty || next.isEmpty) {
      setState(() {
        _pwMsg = 'Fill in both fields.';
        _pwOk = false;
      });
      return;
    }
    setState(() {
      _pwBusy = true;
      _pwMsg = null;
    });
    try {
      final r = await widget.api.post('/me/password', {
        'current_password': cur,
        'new_password': next,
      });
      if (r.statusCode == 204) {
        setState(() {
          _pwMsg = 'Password updated.';
          _pwOk = true;
        });
        _curPwCtrl.clear();
        _newPwCtrl.clear();
      } else if (r.statusCode == 404) {
        setState(() {
          _pwMsg = 'Password change is not enabled.';
          _pwOk = false;
        });
      } else {
        setState(() {
          _pwMsg = 'Current password was not accepted.';
          _pwOk = false;
        });
      }
    } catch (_) {
      setState(() {
        _pwMsg = 'Request failed.';
        _pwOk = false;
      });
    } finally {
      if (mounted) setState(() => _pwBusy = false);
    }
  }

  Future<void> _sendEmailCode() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (newEmail.isEmpty) {
      setState(() {
        _emailMsg = 'Enter a new email address.';
        _emailOk = false;
      });
      return;
    }
    setState(() {
      _emailBusy = true;
      _emailMsg = null;
    });
    try {
      final r = await widget.api.post('/me/email/change', {
        'new_email': newEmail,
      });
      if (r.statusCode == 404) {
        setState(() {
          _emailMsg = 'Email change is not enabled.';
          _emailOk = false;
        });
      } else if (r.statusCode == 200) {
        setState(() {
          _emailMsg = 'We sent a verification code to $newEmail.';
          _emailOk = true;
          _emailVerifyVisible = true;
        });
      } else {
        setState(() {
          _emailMsg = 'That email could not be used.';
          _emailOk = false;
        });
      }
    } catch (_) {
      setState(() {
        _emailMsg = 'Request failed.';
        _emailOk = false;
      });
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _verifyEmailCode() async {
    final t = _emailTokenCtrl.text.trim();
    if (t.isEmpty) {
      setState(() {
        _emailMsg = 'Enter the verification code.';
        _emailOk = false;
      });
      return;
    }
    setState(() {
      _emailBusy = true;
      _emailMsg = null;
    });
    try {
      final r = await widget.api.post('/me/email/verify', {'token': t});
      if (r.statusCode == 404) {
        setState(() {
          _emailMsg = 'Email change is not enabled.';
          _emailOk = false;
        });
      } else if (r.statusCode == 200) {
        setState(() {
          _emailMsg = 'Your email has been updated.';
          _emailOk = true;
          _emailVerifyVisible = false;
        });
        _newEmailCtrl.clear();
        _emailTokenCtrl.clear();
      } else {
        setState(() {
          _emailMsg = 'That code was not accepted.';
          _emailOk = false;
        });
      }
    } catch (_) {
      setState(() {
        _emailMsg = 'Request failed.';
        _emailOk = false;
      });
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Security', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        PortalCard(
          title: 'Two-factor methods',
          children: [
            if (_mfaLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_factors.isEmpty)
              EmptyHint(_mfaEmptyHint ?? 'No second factors registered.')
            else
              for (final raw in _factors) _factorTile(raw as Map),
            MessageBanner(
              _mfaMessage,
              ok: _mfaMessage == 'Second factor removed.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: _mfaBusy ? null : _beginTotp,
                  child: const Text('Add authenticator app'),
                ),
              ],
            ),
            if (_totpPanelOpen) ...[
              const Divider(height: 28),
              const Text(
                'Add this secret to your authenticator app, then enter the 6-digit code to confirm.',
              ),
              const SizedBox(height: 8),
              if (_pendingSecret.isNotEmpty) KvRow('Secret', _pendingSecret),
              if (_pendingUri.isNotEmpty)
                SelectableText(
                  _pendingUri,
                  style: const TextStyle(color: Color(0xFF6366F1)),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _totpLabelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Device name (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _totpCodeCtrl,
                decoration: const InputDecoration(labelText: '6-digit code'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _totpBusy ? null : _confirmTotp,
                  child: _totpBusy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify and save'),
                ),
              ),
              MessageBanner(_totpMsg, ok: false),
            ],
          ],
        ),
        PasskeyEnrollmentCard(api: widget.api, onEnrolled: _loadMfa),
        RecoveryCodesCard(api: widget.api),
        TrustedDevicesCard(api: widget.api),
        PortalCard(
          title: 'Change password',
          children: [
            TextField(
              controller: _curPwCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newPwCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _pwBusy ? null : _changePassword,
                child: _pwBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ),
            MessageBanner(_pwMsg, ok: _pwOk),
          ],
        ),
        PortalCard(
          title: 'Change email',
          children: [
            Text(
              'We send a verification code to the new address. Enter it below to confirm the change.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newEmailCtrl,
              decoration: const InputDecoration(labelText: 'New email'),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _emailBusy ? null : _sendEmailCode,
                child: _emailBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send verification code'),
              ),
            ),
            if (_emailVerifyVisible) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _emailTokenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _emailBusy ? null : _verifyEmailCode,
                  child: const Text('Confirm new email'),
                ),
              ),
            ],
            MessageBanner(_emailMsg, ok: _emailOk),
          ],
        ),
      ],
    );
  }

  Widget _factorTile(Map f) {
    final id = f['id']?.toString() ?? '';
    var meta = f['method']?.toString() ?? '';
    if (f['added_at'] != null) {
      final addedAt = f['added_at'].toString();
      meta +=
          ' · added ${addedAt.substring(0, addedAt.length < 10 ? addedAt.length : 10)}';
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(f['label']?.toString() ?? f['method']?.toString() ?? ''),
      subtitle: Text(meta),
      trailing: TextButton(
        onPressed: _mfaBusy ? null : () => _removeFactor(id),
        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
        child: const Text('Remove'),
      ),
    );
  }
}
