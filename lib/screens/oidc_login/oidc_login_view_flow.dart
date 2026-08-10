part of 'oidc_login_screen.dart';

extension _OidcLoginViewFlow on _OidcLoginScreenState {
  Widget _buildShell(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      // 品牌化背景：柔和的品牌色渐变（产品感），深色/浅色各自适配。
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? [
                    AppColors.primaryDark.withValues(alpha: 0.45),
                    theme.scaffoldBackgroundColor,
                  ]
                : [
                    AppColors.primary.withValues(alpha: 0.6),
                    theme.scaffoldBackgroundColor,
                  ],
          ),
        ),
        child: Stack(
          children: [
            // 装饰光斑（Vercel 登录质感）：柔和的品牌色光晕。
            Positioned(
              top: -80,
              right: -60,
              child: _GlowOrb(
                size: 220,
                color: dark
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppColors.primaryTint.withValues(alpha: 0.35),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -70,
              child: _GlowOrb(
                size: 260,
                color: dark
                    ? AppColors.accentBlue.withValues(alpha: 0.08)
                    : AppColors.accentBlue.withValues(alpha: 0.18),
              ),
            ),
            // 装饰性背景场景（orbit/shield/nodes）——纯装饰，不拦截、无语义。
            Positioned.fill(child: LoginBackdrop(brightness: theme.brightness)),
            ResponsiveEntryCard(
              // 登录头需要容纳主题 + 语言两个自适应下拉并排，默认 440 过窄。
              maxWidth: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 主题选择靠左、语言选择靠右（spaceBetween 分隔）；两者都是
                  // DropdownMenu：菜单统一向下弹出、圆角卡片、宽度贴合文字。
                  // Wrap 而非 Row：窄屏（手机）放不下时语言选择换行右对齐，
                  // 不会溢出。
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runAlignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _HoverTint(child: ThemeDropdown(compact: true, enabled: !_loading)),
                      _HoverTint(child: LanguageDropdown(compact: true, enabled: !_loading)),
                      if (!kIsWeb)
                        IconButton(
                          onPressed: _loading ? null : _openNativeSettings,
                          tooltip: AppStrings.of(context).settings,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 品牌区：租户配置优先，缺省时展示产品默认品牌。
                  if (_brandName != null || _brandLogoUrl != null) ...[
                    BrandingHeader(
                      brandLogoUrl: _brandLogoUrl,
                      brandName: _brandName,
                      brandColor: _brandColor,
                    ),
                  ] else
                    _defaultBranding(context),
                  const SizedBox(height: 16),
                  // 副标语 + 安全徽章：价值主张与信任信号。
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr(
                            'Enterprise-grade identity & access management',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildView(),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('© {year} snaplink · secure identity platform', {
                      'year': '2026',
                    }),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 默认品牌区：产品徽标 + 名称 + 副标题（无租户品牌配置时展示）。
  Widget _defaultBranding(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.shield_outlined,
            size: 28,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('snaplink console'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Identity & Access Management'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
          Text(
            context.tr(
              'No sign-in methods are available for this application.',
            ),
          ),
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
    allowTrustDevice: kIsWeb,
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

/// 装饰光斑：模糊圆形渐变（仅装饰，不拦截交互）。
class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// 悬停/键盘焦点底色：一次性 ≤150ms 颜色过渡，禁止连续动画。焦点态（如
/// Tab 到下拉箭头）与悬停态共用同一底色，保证键盘用户有可见反馈。
class _HoverTint extends StatefulWidget {
  final Widget child;

  const _HoverTint({required this.child});

  @override
  State<_HoverTint> createState() => _HoverTintState();
}

class _HoverTintState extends State<_HoverTint> {
  bool _hovered = false;
  bool _focused = false;

  bool get _active => _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Focus(
      // 仅观察子级焦点（下拉箭头按钮），自身不参与 Tab 遍历。
      canRequestFocus: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _active
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
