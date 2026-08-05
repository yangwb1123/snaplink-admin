import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/sso_client.dart';

/// Create/edit form for an [AdminClient]. Pass [existing] to edit; omit to create.
class ClientFormDialog extends StatefulWidget {
  final SSOAdminClient client;
  final Map<String, dynamic>? existing;

  const ClientFormDialog({super.key, required this.client, this.existing});

  bool get isEdit => existing != null;

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _redirectUrisController;
  late final TextEditingController _loginPageUriController;
  late final TextEditingController _allowedScopesController;
  late final TextEditingController _allowedAuthenticatorsController;
  late final TextEditingController _secretController;
  String _tokenStrategy = 'jwt';
  bool _active = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _idController = TextEditingController(
      text: existing?['id']?.toString() ?? '',
    );
    _nameController = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    _redirectUrisController = TextEditingController(
      text: _joinList(existing?['redirect_uris']),
    );
    _loginPageUriController = TextEditingController(
      text:
          existing?['login_page_uri']?.toString() ??
          existing?['loginPageUri']?.toString() ??
          '',
    );
    _allowedScopesController = TextEditingController(
      text: _joinList(existing?['allowed_scopes']),
    );
    _allowedAuthenticatorsController = TextEditingController(
      text: _joinList(
        existing?['allowed_authenticators'] ??
            existing?['allowedAuthenticators'],
      ),
    );
    _secretController = TextEditingController();
    final strategy =
        existing?['token_strategy']?.toString() ??
        existing?['tokenStrategy']?.toString();
    if (strategy == 'jwt' || strategy == 'session') _tokenStrategy = strategy!;
    _active = existing?['active'] == true || existing == null;
  }

  static String _joinList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).join('\n');
    return '';
  }

  static List<String> _splitList(String text) => text
      .split(RegExp(r'[,\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  static String? _validateRedirectUris(String? value) {
    for (final raw in _splitList(value ?? '')) {
      final uri = Uri.tryParse(raw);
      if (uri == null ||
          !uri.hasScheme ||
          uri.fragment.isNotEmpty ||
          uri.userInfo.isNotEmpty) {
        return 'Invalid redirect URI: $raw';
      }
    }
    return null;
  }

  static String? _validateLoginPageUri(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return 'Use an HTTPS login page URI (or localhost HTTP).'.localized;
    }
    if (uri.scheme == 'https') return null;
    final isLoopback =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (uri.scheme == 'http' && isLoopback) return null;
    return 'Use an HTTPS login page URI (or localhost HTTP).'.localized;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _redirectUrisController.dispose();
    _loginPageUriController.dispose();
    _allowedScopesController.dispose();
    _allowedAuthenticatorsController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'name': _nameController.text.trim(),
      'redirect_uris': _splitList(_redirectUrisController.text),
      'login_page_uri': _loginPageUriController.text.trim(),
      'allowed_scopes': _splitList(_allowedScopesController.text),
      'allowed_authenticators': _splitList(
        _allowedAuthenticatorsController.text,
      ),
      'token_strategy': _tokenStrategy,
      'active': _active,
    };
    final secret = _secretController.text.trim();
    if (secret.isNotEmpty) body['secret'] = secret;
    try {
      if (widget.isEdit) {
        final id = widget.existing!['id'].toString();
        await widget.client.updateClient(id, body);
      } else {
        body['id'] = _idController.text.trim();
        await widget.client.createClient(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on SSOError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.isEdit
          ? const LocalizedText('Edit client')
          : const LocalizedText('New client'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _idController,
                enabled: !widget.isEdit,
                decoration: InputDecoration(labelText: 'ID'.localized),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _loginPageUriController,
                decoration: InputDecoration(
                  labelText: 'Login page URI (optional)'.localized,
                  helperText:
                      'Required for federated OIDC/SAML callbacks. Use HTTPS except for local development.'
                          .localized,
                  helperMaxLines: 2,
                ),
                validator: _validateLoginPageUri,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'.localized),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _redirectUrisController,
                decoration: InputDecoration(
                  labelText: 'Redirect URIs'.localized,
                  helperText: 'One per line or comma-separated'.localized,
                ),
                maxLines: 3,
                validator: _validateRedirectUris,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _allowedScopesController,
                decoration: InputDecoration(
                  labelText: 'Allowed scopes'.localized,
                  helperText: 'One per line or comma-separated'.localized,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _allowedAuthenticatorsController,
                decoration: InputDecoration(
                  labelText: 'Allowed authenticators'.localized,
                  helperText:
                      'One per line or comma-separated. Leave blank to accept any authenticator.'
                          .localized,
                  helperMaxLines: 2,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _tokenStrategy,
                decoration: InputDecoration(
                  labelText: 'Token strategy'.localized,
                ),
                items: const [
                  DropdownMenuItem(value: 'jwt', child: LocalizedText('jwt')),
                  DropdownMenuItem(
                    value: 'session',
                    child: LocalizedText('session'),
                  ),
                ],
                onChanged: (v) => setState(() => _tokenStrategy = v ?? 'jwt'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _secretController,
                decoration: InputDecoration(
                  labelText: 'Secret (optional)'.localized,
                  helperText:
                      ('Leave blank to avoid setting a static secret. This '
                              'admin contract does not configure PKCE; create '
                              'public PKCE clients through the Developer Portal '
                              'or deployment configuration.')
                          .localized,
                  helperMaxLines: 4,
                ),
                obscureText: true,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LocalizedText('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const LocalizedText('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const LocalizedText('Save'),
        ),
      ],
    );
  }
}
