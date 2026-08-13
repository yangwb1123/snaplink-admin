import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'dcr_credentials.dart';
import 'dcr_form_controller.dart';
import 'dcr_metadata_form.dart';
import 'dcr_models.dart';
import 'dcr_validation.dart';
import 'developer_api.dart';

class RegisterPanel extends StatefulWidget {
  final DeveloperApi api;
  final DcrDiscovery? discovery;
  final void Function(
    String clientId,
    String registrationAccessToken,
    Map<String, dynamic> registrationSnapshot,
  )
  onManage;

  const RegisterPanel({
    super.key,
    required this.api,
    this.discovery,
    required this.onManage,
  });

  @override
  State<RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends State<RegisterPanel> {
  final _form = DcrFormController();
  final _iatController = TextEditingController();

  bool _submitting = false;
  String? _error;
  String? _completedClientId;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _registrationSnapshot;

  @override
  void dispose() {
    _form.dispose();
    _iatController.dispose();
    _wipeCredentialReferences();
    super.dispose();
  }

  Future<void> _submit() async {
    late final DcrClientMetadata metadata;
    try {
      metadata = _form.metadata();
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    final validation = validateDcrMetadata(
      metadata,
      discovery: widget.discovery,
    );
    if (!validation.isValid) {
      setState(() => _error = validation.message);
      return;
    }

    final initialAccessToken = _iatController.text.trim();
    _iatController.clear();
    setState(() {
      _submitting = true;
      _error = null;
      _completedClientId = null;
    });
    try {
      final result = await widget.api.registerMetadata(
        metadata: metadata,
        initialAccessToken: initialAccessToken.isEmpty
            ? null
            : initialAccessToken,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        // The 201 response echoes accepted registration-only metadata. The
        // request snapshot fills any omitempty values so a just-created app
        // can safely preserve grant_types on its first RFC 7592 PUT.
        _registrationSnapshot = {...metadata.toRegistrationWire(), ...result};
      });
    } on DeveloperApiError catch (error) {
      if (mounted) setState(() => _error = '$error');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to reach Snaplink. Check the connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _manage() {
    final result = _result;
    final snapshot = _registrationSnapshot;
    if (result == null || snapshot == null) return;
    final clientId = result['client_id']?.toString() ?? '';
    final rat = result['registration_access_token']?.toString() ?? '';
    final safeSnapshot = Map<String, dynamic>.from(snapshot)
      ..remove('client_secret')
      ..remove('registration_access_token');
    widget.onManage(clientId, rat, safeSnapshot);
    _eraseOneTimeResult(clientId);
  }

  void _onSubmitted() {
    if (!_submitting &&
        _result == null &&
        (widget.discovery == null ||
            widget.discovery!.registrationEnabled)) {
      _submit();
    }
  }

  void _eraseOneTimeResult([String? clientId]) {
    final id = clientId ?? _result?['client_id']?.toString();
    setState(() {
      _completedClientId = id;
      _wipeCredentialReferences();
    });
  }

  void _wipeCredentialReferences() {
    _result = null;
    _registrationSnapshot = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final registrationEnabled =
        widget.discovery == null || widget.discovery!.registrationEnabled;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Intro: what this panel does, the PKCE S256 stance, and the
        // one-time display guarantee (RFC 7591 register surface).
        const _RegisterIntro(),
        if (!registrationEnabled) ...[
          const SizedBox(height: 12),
          _Notice(
            icon: Icons.warning_amber_rounded,
            message:
                'Snaplink discovery does not advertise a registration_endpoint. '
                'Registration is disabled for this deployment.',
            warning: true,
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DcrMetadataForm(
                  controller: _form,
                  discovery: widget.discovery,
                  onChanged: () => setState(() => _error = null),
                ),
                const SizedBox(height: 16),
                SensitiveTokenField(
                  controller: _iatController,
                  label: 'Initial Access Token',
                  hintText: context.tr(
                    'Leave blank only when open registration is enabled',
                  ),
                  enabled:
                      !_submitting &&
                      _result == null &&
                      registrationEnabled,
                  onSubmitted: (_) => _onSubmitted(),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'The initial access token is sent once and cleared from this form as soon as registration starts.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: _ErrorBanner(message: _error!),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed:
                      _submitting ||
                          _result != null ||
                          !registrationEnabled
                      ? null
                      : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          context.tr(
                            _result == null
                                ? 'Register App'
                                : 'Save or erase issued credentials first',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          OneTimeRegistrationCredentials(
            result: _result!,
            onManage: _manage,
            onWipe: _eraseOneTimeResult,
          ),
        ],
        if (_completedClientId != null) ...[
          const SizedBox(height: 16),
          _Notice(
            icon: Icons.check_circle_outline,
            message:
                'One-time credentials for $_completedClientId were erased from '
                'the registration result.',
          ),
        ],
      ],
    );
  }
}

/// Branded intro banner for the register wizard: icon tile + title + the
/// RFC 7591 registration posture (open or IAT-gated, PKCE S256 for public
/// clients, one-time credential display).
class _RegisterIntro extends StatelessWidget {
  const _RegisterIntro();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.12),
            scheme.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.app_registration, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Register an OAuth 2.0 / OIDC client'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Register an OAuth 2.0 / OIDC client using Snaplink Dynamic Client Registration. Public clients are forced to PKCE S256. Issued credentials are displayed only until you confirm they have been saved.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline callout used for the registration-disabled warning and the
/// post-erase confirmation. Icon + container tinted by severity.
class _Notice extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool warning;

  const _Notice({
    required this.icon,
    required this.message,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = warning
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(message),
              style: TextStyle(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Validation/transport failure banner for the register form.
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(message),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
