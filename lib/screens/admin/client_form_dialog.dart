import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _redirectUrisController.dispose();
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
      title: Text(widget.isEdit ? 'Edit client' : 'New client'),
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
                decoration: const InputDecoration(labelText: 'ID'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _redirectUrisController,
                decoration: const InputDecoration(
                  labelText: 'Redirect URIs',
                  helperText: 'One per line or comma-separated',
                ),
                maxLines: 3,
                validator: _validateRedirectUris,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _allowedScopesController,
                decoration: const InputDecoration(
                  labelText: 'Allowed scopes',
                  helperText: 'One per line or comma-separated',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _allowedAuthenticatorsController,
                decoration: const InputDecoration(
                  labelText: 'Allowed authenticators',
                  helperText:
                      'One per line or comma-separated. Leave blank to accept any authenticator.',
                  helperMaxLines: 2,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _tokenStrategy,
                decoration: const InputDecoration(labelText: 'Token strategy'),
                items: const [
                  DropdownMenuItem(value: 'jwt', child: Text('jwt')),
                  DropdownMenuItem(value: 'session', child: Text('session')),
                ],
                onChanged: (v) => setState(() => _tokenStrategy = v ?? 'jwt'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Secret (optional)',
                  helperText:
                      'Leave blank to avoid setting a static secret. This '
                      'admin contract does not configure PKCE; create public '
                      'PKCE clients through the Developer Portal or deployment '
                      'configuration.',
                  helperMaxLines: 4,
                ),
                obscureText: true,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
