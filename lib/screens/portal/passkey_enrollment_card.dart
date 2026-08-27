import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import '../oidc_login/webauthn_registration.dart';
import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'portal_widgets.dart';

/// Authenticated passkey enrollment, kept separate from TOTP management so a
/// browser ceremony never makes the rest of the security screen unavailable.
/// WebAuthn is browser-only; this card stays self-contained with its own
/// busy/result states.
class PasskeyEnrollmentCard extends StatefulWidget {
  final PortalApi api;
  final VoidCallback onEnrolled;

  const PasskeyEnrollmentCard({
    super.key,
    required this.api,
    required this.onEnrolled,
  });

  @override
  State<PasskeyEnrollmentCard> createState() => _PasskeyEnrollmentCardState();
}

class _PasskeyEnrollmentCardState extends State<PasskeyEnrollmentCard> {
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _ok = false;
    });
    try {
      final begin = await widget.api.post(PortalPaths.webauthnBegin, {
        if (_nameCtrl.text.trim().isNotEmpty)
          'display_name': _nameCtrl.text.trim(),
      });
      if (!mounted) return;
      if (begin.statusCode == 404 || begin.statusCode == 501) {
        setState(() => _message = 'Passkey enrollment is not enabled.');
        return;
      }
      if (begin.statusCode != 200) {
        setState(() => _message = 'Could not start passkey enrollment.');
        return;
      }
      final data = PortalApi.decode(begin);
      final sessionId = data['session_id']?.toString() ?? '';
      final options = data['options'];
      if (sessionId.isEmpty || options == null) {
        setState(
          () => _message = 'The server returned an invalid passkey request.',
        );
        return;
      }
      final credential = await WebAuthnRegistration.create(options);
      if (!mounted) return;
      final finish = await widget.api.post(
        PortalPaths.webauthnFinish(sessionId),
        credential,
      );
      if (!mounted) return;
      if (finish.statusCode == 201) {
        _nameCtrl.clear();
        setState(() {
          _ok = true;
          _message = 'Passkey added.';
        });
        widget.onEnrolled();
        return;
      }
      setState(() => _message = 'The passkey could not be verified.');
    } on FormatException catch (_) {
      if (mounted) setState(() => _message = 'The passkey request is invalid.');
    } on StateError catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'Passkey enrollment failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PortalCard(
      title: 'Add a passkey',
      children: [
        Text(
          context.tr('Use a biometric or security key for future sign-ins.'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.name,
          decoration: InputDecoration(
            labelText: context.tr('Passkey name (optional)'),
            prefixIcon: const Icon(Icons.fingerprint),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _enroll,
            icon: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fingerprint),
            label: Text(context.tr('Add a passkey')),
          ),
        ),
        MessageBanner(_message, ok: _ok),
      ],
    );
  }
}
