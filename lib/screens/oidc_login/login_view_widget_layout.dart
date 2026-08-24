part of 'login_view_widget.dart';

/// Login form composition kept separate from the stateful field primitives.
/// This keeps the public widget and its mutable password-visibility state small
/// while preserving the exact widget tree used by the hosted-login contracts.
extension _LoginViewWidgetLayout on _LoginViewWidgetState {
  Widget _buildLoginView(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 768;
    final builtinProviders = widget.providers
        .where((item) => item.builtin)
        .toList();
    final federatedProviders = widget.providers
        .where(
          (item) =>
              item.isFederated &&
              (!widget.usesFederatedProvider || item.id != widget.provider),
        )
        .toList();
    final selected = _descriptorFor(widget.provider);
    final selectedBuiltin = builtinProviders.any(
      (item) => item.id == widget.provider,
    );

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(strings.signIn, style: theme.textTheme.titleLarge),
          ),
          SizedBox(height: narrow ? 16 : 20),
          if (builtinProviders.length > 1) ...[
            _providerSelector(
              strings,
              builtinProviders,
              selectedBuiltin: selectedBuiltin,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.signupConfirmed != null)
            _notice(
              context.tr(widget.signupConfirmed!),
              Icons.check_circle_outline,
              top: 12,
              live: true,
            ),
          _providerForm(context, strings, selected),
          if (widget.error != null) _errorNotice(context),
          SizedBox(height: narrow ? 16 : 20),
          _submitButton(context, strings, selected),
          if (widget.provider == 'password')
            ..._passwordActions(context, strings, theme),
          if (federatedProviders.isNotEmpty)
            ..._federatedActions(context, strings, theme, federatedProviders),
        ],
      ),
    );
  }

  Widget _providerSelector(
    AppStrings strings,
    List<LoginProviderDescriptor> providers, {
    required bool selectedBuiltin,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedBuiltin ? widget.provider : null,
      hint: Text(strings.provider),
      items: [
        for (final item in providers)
          DropdownMenuItem(value: item.id, child: Text(item.displayName)),
      ],
      onChanged: widget.loading
          ? null
          : (value) {
              if (value != null) widget.onProviderChanged(value);
            },
      decoration: InputDecoration(labelText: strings.provider).applyDefaults(
        AppTheme.loginInputDecoration(Theme.of(context).brightness),
      ),
    );
  }

  Widget _providerForm(
    BuildContext context,
    AppStrings strings,
    LoginProviderDescriptor selected,
  ) {
    if (widget.usesFederatedProvider) {
      return _notice(
        context.tr('Continue to {provider} to sign in.', {
          'provider': selected.displayName,
        }),
        Icons.open_in_new,
        vertical: 16,
      );
    }
    if (widget.provider == 'webauthn') {
      return _notice(
        context.tr('Choose a passkey to sign in without a password.'),
        Icons.fingerprint,
        vertical: 16,
      );
    }
    if (widget.usesCodeProvider) return _codeForm(context);
    if (widget.usesTotpProvider) return _totpForm(strings);
    return _passwordForm(strings);
  }

  Widget _errorNotice(BuildContext context) {
    return _notice(
      context.tr(widget.error!),
      Icons.error_outline,
      top: 16,
      // Sentry error banner: explicit semantic foreground over the M3
      // error-container background.
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.dangerTint
          : AppColors.dangerDark,
      contained: true,
      live: true,
    );
  }

  Widget _submitButton(
    BuildContext context,
    AppStrings strings,
    LoginProviderDescriptor selected,
  ) {
    final label = widget.usesFederatedProvider
        ? selected.effectiveButtonLabel
        : widget.provider == 'webauthn'
        ? context.tr('Sign in with passkey')
        : strings.signIn;
    return PressableScale(
      child: FilledButton(
        onPressed: widget.loading ? null : widget.onSubmit,
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        child: widget.loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }

  List<Widget> _passwordActions(
    BuildContext context,
    AppStrings strings,
    ThemeData theme,
  ) {
    final narrow = MediaQuery.sizeOf(context).width < 768;
    final linkStyle = TextButton.styleFrom(
      minimumSize: const Size(48, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );

    Widget linkButton(String label, VoidCallback onPressed) => TextButton(
      onPressed: widget.loading ? null : onPressed,
      style: linkStyle,
      child: Text(label, softWrap: true),
    );

    final linkCluster = LayoutBuilder(
      builder: (context, constraints) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 8,
        runSpacing: 0,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: linkButton(strings.forgotPassword, widget.onForgotPassword),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: linkButton(strings.signUp, widget.onSignUp),
          ),
        ],
      ),
    );

    return [
      SizedBox(height: narrow ? 12 : 16),
      linkCluster,
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.loading ? null : widget.onHomeRealm,
          style: linkStyle,
          icon: Icon(Icons.business_outlined, color: theme.colorScheme.primary),
          label: Text(context.tr('Use organization sign-in'), softWrap: true),
        ),
      ),
    ];
  }

  List<Widget> _federatedActions(
    BuildContext context,
    AppStrings strings,
    ThemeData theme,
    List<LoginProviderDescriptor> providers,
  ) {
    final narrow = MediaQuery.sizeOf(context).width < 768;
    return [
      SizedBox(height: narrow ? 16 : 20),
      Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(strings.orDivider, style: theme.textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
      SizedBox(height: narrow ? 12 : 16),
      for (final item in providers)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _FederatedProviderButton(
            provider: item,
            loading: widget.loading,
            onPressed: () => widget.onFederatedSignIn(item.id),
          ),
        ),
    ];
  }
}
