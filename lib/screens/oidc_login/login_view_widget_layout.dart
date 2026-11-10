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
          _providerPanel(context, strings, selected),
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
    final scheme = Theme.of(context).colorScheme;
    final selectedProvider = selectedBuiltin ? widget.provider : null;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        container: true,
        child: RadioGroup<String>(
          groupValue: selectedProvider,
          onChanged: widget.loading
              ? (_) {}
              : (value) {
                  if (value != null) widget.onProviderChanged(value);
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  strings.provider,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final item in providers)
                RadioListTile<String>(
                  value: item.id,
                  enabled: !widget.loading,
                  selected: selectedProvider == item.id,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  activeColor: scheme.primary,
                  title: Text(item.displayName, softWrap: true),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _providerPanel(
    BuildContext context,
    AppStrings strings,
    LoginProviderDescriptor selected,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                child: IgnorePointer(
                  ignoring: widget.loading,
                  child: _providerForm(context, strings, selected),
                ),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 16),
                _errorNotice(context),
              ],
              const SizedBox(height: 16),
              _submitButton(context, strings, selected),
            ],
          ),
        ),
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
            ? Semantics(
                label: strings.loading,
                child: const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Text(label, softWrap: true, textAlign: TextAlign.center),
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

  Widget _federatedProviderButton(
    BuildContext context,
    LoginProviderDescriptor provider,
  ) {
    // Keep the existing compact renderer for ordinary labels. Long labels
    // use the explicit flexible row below so the icon never competes with an
    // unbounded Text child on a narrow viewport.
    if (provider.effectiveButtonLabel.length <= 40) {
      return _FederatedProviderButton(
        provider: provider,
        loading: widget.loading,
        onPressed: () => widget.onFederatedSignIn(provider.id),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _parseFederatedButtonColor(provider.buttonColor);
    final tint = color?.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.14 : 0.10,
    );
    final iconColor = color ?? scheme.primary;
    final iconUrl = provider.safeIconUrl(ProductApiOrigin.baseUri);
    final icon = iconUrl == null
        ? Icon(Icons.login, color: iconColor)
        : Image.network(
            iconUrl,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(Icons.login, color: iconColor),
          );

    return OutlinedButton(
      onPressed: widget.loading
          ? null
          : () => widget.onFederatedSignIn(provider.id),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        backgroundColor: tint,
        foregroundColor: scheme.onSurface,
        side: color == null
            ? null
            : BorderSide(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(provider.effectiveButtonLabel),
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Color? _parseFederatedButtonColor(String raw) {
    final match = RegExp(
      r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final hex = match.group(1)!;
    final flutterHex = hex.length == 6
        ? 'ff$hex'
        : '${hex.substring(6)}${hex.substring(0, 6)}';
    return Color(int.parse(flutterHex, radix: 16));
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
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: Semantics(
                container: true,
                child: _federatedProviderButton(context, item),
              ),
            ),
          ),
        ),
    ];
  }
}
