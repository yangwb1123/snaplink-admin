part of 'oidc_login_screen.dart';

extension _OidcLoginViewFlow on _OidcLoginScreenState {
  Widget _buildShell(BuildContext context) {
    return Scaffold(
      body: ResponsiveEntryCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LanguageToggle(),
            const SizedBox(height: 8),
            if (_brandName != null || _brandLogoUrl != null) ...[
              BrandingHeader(
                brandLogoUrl: _brandLogoUrl,
                brandName: _brandName,
                brandColor: _brandColor,
              ),
              const SizedBox(height: 16),
            ],
            _buildView(),
          ],
        ),
      ),
    );
  }

  Widget _buildView() {
    if (_checkingFederatedReturn) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    switch (_view) {
      case _View.login:
        return _loginView();
      case _View.forgotPassword:
        return ForgotPasswordView(
          identifierController: _forgotIdCtrl,
          loading: _loading,
          message: _forgotMessage,
          error: _error,
          onSubmit: _submitForgotPassword,
          onBack: _showLogin,
        );
      case _View.resetPassword:
        return ResetPasswordView(
          passwordController: _resetPassCtrl,
          confirmController: _resetConfirmCtrl,
          tokenAvailable: _resetToken != null,
          loading: _loading,
          error: _error,
          onSubmit: _submitResetPassword,
          onBack: _showLogin,
        );
      case _View.signup:
        return SignupView(
          usernameController: _signupUserCtrl,
          emailController: _signupEmailCtrl,
          passwordController: _signupPassCtrl,
          confirmController: _signupConfirmCtrl,
          loading: _loading,
          error: _error,
          onSubmit: _submitSignup,
          onBack: _showLogin,
        );
      case _View.pendingVerification:
        return AccountFlowResultView(
          title: 'Check your email',
          message:
              'Your registration is pending. Use the verification link sent '
              'to your email address to finish creating the account.',
          onBack: _showLogin,
        );
      case _View.emailVerification:
        return EmailVerificationView(
          tokenAvailable: _verificationToken != null,
          loading: _loading,
          error: _error,
          onVerify: _submitEmailVerification,
          onBack: _showLogin,
        );
      case _View.accountResult:
        return AccountFlowResultView(
          title: _accountResultTitle,
          message: _accountResultMessage,
          icon: _accountResultIcon,
          onBack: _showLogin,
        );
      case _View.mfa:
        return _mfaView();
      case _View.consent:
        return _consentView();
      case _View.success:
        return Text(AppStrings.of(context).signedIn);
    }
  }

  Widget _loginView() {
    if (_providerDiscoveryComplete && _providers.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.of(context).signIn,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Text('No sign-in methods are available for this application.'),
        ],
      );
    }
    return LoginViewWidget(
      provider: _provider,
      providers: _providers,
      signupConfirmed: _signupConfirmed,
      userCtrl: _userCtrl,
      passCtrl: _passCtrl,
      codeTargetCtrl: _codeTargetCtrl,
      providerCodeCtrl: _providerCodeCtrl,
      codeSent: _codeSent,
      codeMessage: _codeMessage,
      loading: _loading,
      error: _error,
      usesFederatedProvider: _usesFederatedProvider,
      usesCodeProvider: _usesCodeProvider,
      usesTotpProvider: _usesTotpProvider,
      magicLinkToken: _magicLinkToken,
      onSubmit: _submitLogin,
      onSendCode: _sendProviderCode,
      onHomeRealm: _discoverHomeRealm,
      onForgotPassword: () => _update(() {
        _forgotIdCtrl.text = _userCtrl.text;
        _forgotMessage = null;
        _view = _View.forgotPassword;
        _error = null;
      }),
      onSignUp: () => _update(() {
        _view = _View.signup;
        _error = null;
      }),
      onProviderChanged: (provider) => _update(() {
        _provider = provider;
        _codeSent = false;
        _codeMessage = null;
        _error = null;
      }),
      onFederatedSignIn: _signInWithFederated,
    );
  }

  Widget _mfaView() => MfaView(
    mfaMethods: _mfaMethods,
    selectedMfaMethod: _selectedMfaMethod,
    mfaMethodData: _mfaMethodData,
    mfaCodeCtrl: _mfaCodeCtrl,
    trustThisDevice: _trustThisDevice,
    loading: _loading,
    error: _error,
    onMethodChanged: (method) => _update(() => _selectedMfaMethod = method),
    onTrustChanged: (value) => _update(() => _trustThisDevice = value ?? false),
    onSubmit: _submitMfa,
    onBack: () => _discardMfaChallenge(null),
  );

  Widget _consentView() => ConsentView(
    clientName: _consentClientName,
    clientId: _params.clientId,
    summary: _consentSummary,
    error: _error,
    loading: _loading,
    onAllow: () => _submitConsent(true),
    onDeny: () => _submitConsent(false),
  );
}
