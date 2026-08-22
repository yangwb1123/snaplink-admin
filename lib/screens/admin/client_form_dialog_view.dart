part of 'client_form_dialog.dart';

extension _ClientFormDialogView on _ClientFormDialogState {
  Widget _buildClientFormDialog(BuildContext context) => AlertDialog(
    title: widget.isEdit
        ? const LocalizedText('Edit client')
        : const LocalizedText('Create client'),
    content: _clientForm(context),
    actions: _clientFormActions(context),
  );

  Widget _clientForm(BuildContext context) => SizedBox(
    width: 560,
    child: SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _clientFormFields(context),
        ),
      ),
    ),
  );

  List<Widget> _clientFormFields(BuildContext context) => [
    TextFormField(
      controller: _idController,
      enabled: !widget.isEdit,
      autofocus: !widget.isEdit,
      decoration: InputDecoration(
        labelText: 'ID'.localized,
        helperText: 'Immutable after creation.'.localized,
      ),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Required'.localized : null,
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
      validator: _ClientFormDialogState._validateLoginPageUri,
    ),
    const SizedBox(height: 8),
    TextFormField(
      controller: _nameController,
      decoration: InputDecoration(labelText: 'Name'.localized),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Required'.localized : null,
    ),
    const SizedBox(height: 8),
    TextFormField(
      controller: _redirectUrisController,
      decoration: InputDecoration(
        labelText: 'Redirect URIs'.localized,
        helperText: 'One per line or comma-separated'.localized,
      ),
      maxLines: 3,
      validator: _ClientFormDialogState._validateRedirectUris,
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
    // R31：2 项短枚举 → SegmentedButton（替代 Token strategy 下拉）。
    LocalizedText(
      'Token strategy',
      style: Theme.of(context).textTheme.labelLarge,
    ),
    const SizedBox(height: 8),
    SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'jwt', label: LocalizedText('jwt')),
        ButtonSegment(value: 'session', label: LocalizedText('session')),
      ],
      selected: {_tokenStrategy},
      showSelectedIcon: false,
      onSelectionChanged: _selectTokenStrategy,
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
      onChanged: _setActive,
    ),
  ];

  List<Widget> _clientFormActions(BuildContext context) => [
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
  ];
}
