import 'dart:async';
import 'package:sso_admin/theme/app_colors.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../i18n/app_strings.dart';
import '../../services/browser_auth_response.dart';
import '../../services/browser_navigation.dart';
import '../../services/product_api_origin.dart';
import '../../session.dart';
import '../../widgets/responsive_entry_card.dart';
import '../settings_screen.dart';
import 'account_flow_views.dart';
import 'authorization_delivery.dart';
import 'branding_header.dart';
import 'consent_view.dart';
import 'federated_login.dart';
import 'hosted_login_location.dart';
import 'hosted_login_models.dart';
import 'jarm_completion.dart';
import 'language_toggle.dart';
import 'login_view_widget.dart';
import 'mfa_view.dart';
import 'oauth_params.dart';
import 'oidc_login_api.dart';
import 'trusted_device_token.dart';
import 'webauthn_assertion.dart';

part 'oidc_account_flow.dart';
part 'oidc_authorization_flow.dart';
part 'oidc_challenge_flow.dart';
part 'oidc_login_view_flow.dart';
part 'oidc_provider_flow.dart';

enum _View {
  login,
  forgotPassword,
  resetPassword,
  signup,
  pendingVerification,
  emailVerification,
  accountResult,
  mfa,
  consent,
  success,
}

/// OIDC login screen: RFC-compliant auth with password, code-based,
/// federated, WebAuthn, self-service account flows, and B2B realm routing.
class OidcLoginScreen extends StatefulWidget {
  /// Used as client_id when the URL carries no RP client_id — the first-party
  /// case (direct /login/ or /admin/ access).
  final String? defaultClientId;
  final OidcLoginApi? api;
  final Uri? routeUri;

  const OidcLoginScreen({
    super.key,
    this.defaultClientId,
    this.api,
    this.routeUri,
  });

  @override
  State<OidcLoginScreen> createState() => _OidcLoginScreenState();
}

/// Redirect target validation for first-party login.
String _safeRedirectTarget(Uri current) {
  final values = current.queryParametersAll['redirect'] ?? const <String>[];
  // Never resolve an ambiguous continuation by silently choosing the last
  // duplicate query value.
  if (values.length != 1) return '/admin/';
  final raw = values.single;
  if (raw.isEmpty || raw.contains('\\')) return '/admin/';
  try {
    final target = Uri.parse(raw);
    if (!current.hasAuthority) {
      if (target.hasScheme ||
          target.hasAuthority ||
          !target.path.startsWith('/')) {
        return '/admin/';
      }
      return raw;
    }
    final resolved = current.resolve(raw);
    if (!resolved.hasAuthority || resolved.origin != current.origin) {
      return '/admin/';
    }
  } catch (_) {
    return '/admin/';
  }
  return raw;
}

class _OidcLoginScreenState extends State<OidcLoginScreen> {
  late final Uri _routeUri = widget.routeUri ?? Uri.base;
  late final OAuthParams _params = OAuthParams.fromUri(_routeUri);
  late final HostedLoginRoute _route = HostedLoginRoute.fromUri(_routeUri);
  late final String? _federatedContinuationId = hostedFederatedTransactionId(
    _routeUri,
  );
  late OidcLoginApi _api;
  late final bool _ownsApi;

  _View _view = _View.login;
  String _provider = 'password';
  List<LoginProviderDescriptor> _providers = const [
    LoginProviderDescriptor.password(),
  ];
  bool _providerDiscoveryComplete = false;
  bool _serverOwnedAuthorizationRequestSupported = false;

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeTargetCtrl = TextEditingController();
  final _providerCodeCtrl = TextEditingController();
  bool _codeSent = false;
  String? _codeMessage;
  bool _loading = false;
  String? _error;

  String? _brandName;
  String? _brandLogoUrl;
  Color? _brandColor;
  bool _clientBrandingApplied = false;

  String _mfaChallengeId = '';
  List<String> _mfaMethods = const [];
  Map<String, Map<String, String>> _mfaMethodData = const {};
  String? _selectedMfaMethod;
  final _mfaCodeCtrl = TextEditingController();
  bool _trustThisDevice = false;

  String _loginTransactionId = '';
  String _consentChallengeId = '';
  String _consentClientName = '';
  ConsentRequestSummary _consentSummary = const ConsentRequestSummary.invalid();

  final _forgotIdCtrl = TextEditingController();
  final _resetPassCtrl = TextEditingController();
  final _resetConfirmCtrl = TextEditingController();
  final _signupUserCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _signupConfirmCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  String? _forgotMessage;
  String? _signupConfirmed;
  String _accountResultTitle = '';
  String _accountResultMessage = '';
  IconData _accountResultIcon = Icons.check_circle_outline;
  String? _magicLinkToken;
  String? _resetToken;
  String? _verificationToken;

  bool _checkingFederatedReturn = true;

  String get _effectiveClientId => _params.clientId.isNotEmpty
      ? _params.clientId
      : (widget.defaultClientId ?? '');

  bool get _usesCodeProvider =>
      {'phone', 'email', 'magiclink'}.contains(_provider);

  bool get _usesTotpProvider => _provider == 'totp';

  bool get _usesFederatedProvider {
    for (final descriptor in _providers) {
      if (descriptor.id == _provider) return descriptor.isFederated;
    }
    return _provider.isNotEmpty &&
        !LoginProviderDescriptor.builtinProviderIds.contains(_provider);
  }

  bool get _isRpFlow =>
      _params.clientId.isNotEmpty &&
      (_params.redirectUri.isNotEmpty ||
          _params.requestUri.isNotEmpty ||
          _params.request.isNotEmpty);

  bool get _requestsTokenResponse => _params.responseType
      .split(RegExp(r'\s+'))
      .any((value) => value == 'token' || value == 'id_token');

  bool get _usesJarm =>
      _params.responseMode == 'jwt' || _params.responseMode.endsWith('.jwt');

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    _api = widget.api ?? OidcLoginApi();
    _provider = _params.provider.isNotEmpty ? _params.provider : 'password';
    _userCtrl.text = _params.loginHint;
    _magicLinkToken = _route.magicLinkToken;
    _resetToken = _route.resetToken;
    _verificationToken = _route.verificationToken;
    if (_routeUri.queryParametersAll.containsKey('device_token')) {
      BrowserNavigation.replaceState(
        hostedLoginLocationWithoutDeviceCredential(_routeUri),
      );
    }
    _applyInitialFlow();

    if (_routeUri.queryParameters['verified'] == 'email') {
      _signupConfirmed = 'Email verified.';
    }

    _loadBranding();
    if (_route.requiresAuthentication) {
      _checkFederatedReturn();
    } else {
      _checkingFederatedReturn = false;
    }
    if (_effectiveClientId.isNotEmpty &&
        _route.requiresAuthentication &&
        _federatedContinuationId == null &&
        !FederatedLogin.hasPendingReturn(location: _routeUri) &&
        !_route.shouldAutoSubmitMagicLink &&
        !_params.hasPromptNone) {
      _probeProviders();
    }
  }

  void _applyInitialFlow() {
    switch (_route.flow) {
      case HostedLoginFlow.forgotPassword:
        _view = _View.forgotPassword;
        break;
      case HostedLoginFlow.resetPassword:
        _view = _View.resetPassword;
        break;
      case HostedLoginFlow.signup:
        _view = _View.signup;
        break;
      case HostedLoginFlow.verifyEmail:
        _view = _View.emailVerification;
        break;
      case HostedLoginFlow.magicLink:
        _provider = 'magiclink';
        _view = _View.login;
        break;
      case HostedLoginFlow.changeEmail:
      case HostedLoginFlow.invitation:
        _view = _View.login;
        break;
      case HostedLoginFlow.login:
        _view = _View.login;
        break;
    }

    if (_route.shouldAutoSubmitMagicLink) {
      _provider = 'magiclink';
      _codeTargetCtrl.text = _route.magicLinkEmail!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _submitLogin());
    } else if (_route.flow == HostedLoginFlow.magicLink &&
        _route.magicLinkEmail != null) {
      _codeTargetCtrl.text = _route.magicLinkEmail!;
    }
  }

  void _update(VoidCallback change) => setState(change);

  Future<void> _openNativeSettings() async {
    final previousOrigin = ProductApiOrigin.baseUri;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    if (!mounted || previousOrigin == ProductApiOrigin.baseUri) {
      return;
    }
    // Credentials, challenges, verifier links, OAuth transaction parameters,
    // and identities all belong to the old deployment. Replacing the whole
    // entry guarantees none can be submitted to the newly configured origin.
    BrowserNavigation.replaceLocation('/login/');
  }

  @override
  void dispose() {
    if (_ownsApi) _api.close();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _codeTargetCtrl.dispose();
    _providerCodeCtrl.dispose();
    _mfaCodeCtrl.dispose();
    _forgotIdCtrl.dispose();
    _resetPassCtrl.dispose();
    _resetConfirmCtrl.dispose();
    _signupUserCtrl.dispose();
    _signupPassCtrl.dispose();
    _signupConfirmCtrl.dispose();
    _signupEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildShell(context);
}
