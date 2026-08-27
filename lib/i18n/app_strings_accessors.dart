part of 'app_strings.dart';

extension AppStringsAccessors on AppStrings {
  // Login screen
  String get signIn => _t('sign_in');
  String get username => _t('username');
  String get password => _t('password');
  String get forgotPassword => _t('forgot_password');
  String get signUp => _t('sign_up');
  String get orDivider => _t('or_divider');
  String get signInWith => _t('sign_in_with');
  String get provider => _t('provider');
  String get signedIn => _t('signed_in');
  String get networkError => _t('network_error');
  String get resetPassword => _t('reset_password');
  String get usernameOrEmail => _t('username_or_email');
  String get sendResetLink => _t('send_reset_link');
  String get back => _t('back');
  String get createAccount => _t('create_account');
  String get emailOptional => _t('email_optional');
  String get verifyIdentity => _t('verify_identity');
  String get verificationCode => _t('verification_code');
  String get verify => _t('verify');
  String get mfaMethodTotp => _t('mfa_method_totp');
  String get mfaMethodOtp => _t('mfa_method_otp');
  String get mfaMethodWebauthn => _t('mfa_method_webauthn');
  String get mfaMethodPush => _t('mfa_method_push');
  String get mfaMethodSms => _t('mfa_method_sms');

  // Settings screen
  String get settings => _t('settings');
  String get language => _t('language');
  String get theme => _t('theme');
  String get themeSystem => _t('theme_system');
  String get themeLight => _t('theme_light');
  String get themeDark => _t('theme_dark');
  String get adminNavMode => _t('admin_nav_mode');
  String get adminNavModeNormal => _t('admin_nav_mode_normal');
  String get adminNavModeProfessional => _t('admin_nav_mode_professional');
  String get ssoBaseUrl => _t('sso_base_url');
  String get ssoBaseUrlHint => _t('sso_base_url_hint');
  String get save => _t('save');
  String get saved => _t('saved');
  String get timezone => _t('timezone');

  // Dashboard
  String get clients => _t('clients');
  String get users => _t('users');
  String get tenants => _t('tenants');
  String get logout => _t('logout');

  // Admin - Common
  String get search => _t('search');
  String get filter => _t('filter');
  String get refresh => _t('refresh');
  String get create => _t('create');
  String get edit => _t('edit');
  String get delete => _t('delete');
  String get cancel => _t('cancel');
  String get confirm => _t('confirm');
  String get retry => _t('retry');
  String get loading => _t('loading');
  String get noData => _t('no_data');
  String get errorOccurred => _t('error_occurred');

  // Admin - Modules
  String get permissions => _t('permissions');
  String get connections => _t('connections');
  String get tokenSecurity => _t('token_security');
  String get webhooks => _t('webhooks');
  String get emergencyAccess => _t('emergency_access');
  String get governance => _t('governance');
  String get cryptoKeys => _t('crypto_keys');
  String get credentials => _t('credentials');
  String get domains => _t('domains');
  String get threatPolicies => _t('threat_policies');
  String get accessPolicies => _t('access_policies');
  String get drMode => _t('dr_mode');
  String get organizations => _t('organizations');
  String get operations => _t('operations');
  String get userSupport => _t('user_support');
  String get liveActivity => _t('live_activity');
  String get adminOperations => _t('admin_operations');
  String get platformOverview => _t('platform_overview');
  String get identityConnections => _t('identity_connections');
  String get tenantOrganizations => _t('tenant_organizations');
  String get tokenExchange => _t('token_exchange');
  String get tokenPolicies => _t('token_policies');
  String get governanceOperations => _t('governance_operations');
  String get tokenSessionSecurity => _t('token_session_security');
  String get authzChecks => _t('authz_checks');
  String get overview => _t('overview');
  String get localUsers => _t('local_users');
  String get scimDirectory => _t('scim_directory');
  String get deviceSecurity => _t('device_security');
  String get usageInsights => _t('usage_insights');
  String get networkPolicies => _t('network_policies');
  String get changeApprovals => _t('change_approvals');
  String get recoveryReleases => _t('recovery_releases');
  String get privacyRetention => _t('privacy_retention');
  String get auditLog => _t('audit_log');
  String get health => _t('health');
  String get ssoAdmin => _t('sso_admin');
  String failedToLoadAdminConsole(Object error) =>
      '${_t('failed_to_load_admin_console')}: $error';

  // Portal
  String get accountTitle => _t('account_title');
  String get accountSubtitle => _t('account_subtitle');
  String get accessToken => _t('access_token');
  String get continueLabel => _t('continue');
  String get security => _t('security');
  String get devices => _t('devices');
  String get sessions => _t('sessions');
  String get activity => _t('activity');
  String get linkedIdentities => _t('linked_identities');
  String get connectedApps => _t('connected_apps');
  String get notifications => _t('notifications');
  String get privacy => _t('privacy');
  String get signOut => _t('sign_out');
  String get redirectingToSignIn => _t('redirecting_to_sign_in');
  String get enterToken => _t('enter_token');
  String get tokenNotAccepted => _t('token_not_accepted');
  String get accountDeleted => _t('account_deleted');
  String get sessionRevoked => _t('session_revoked');
  String get sessionExpired => _t('session_expired');

  // Developer portal
  String get developerPortal => _t('developer_portal');
  String get registerNewApp => _t('register_new_app');
  String get manageExistingApp => _t('manage_existing_app');
  String get retryDiscovery => _t('retry_discovery');

  // First-run setup
  String get setupUnavailable => _t('setup_unavailable');
  String get setupStatusUnknown => _t('setup_status_unknown');
  String get createAdministrator => _t('create_administrator');
  String get createAdministratorDescription =>
      _t('create_administrator_description');
  String get adminUsername => _t('admin_username');
  String get confirmPassword => _t('confirm_password');
  String get firstApplication => _t('first_application');
  String get optional => _t('optional');
  String get firstApplicationDescription => _t('first_application_description');
  String get applicationName => _t('application_name');
  String get redirectUris => _t('redirect_uris');
  String get oneHttpsUriPerLine => _t('one_https_uri_per_line');
  String get createAndFinish => _t('create_and_finish');
  String get skipAndFinish => _t('skip_and_finish');
  String get networkErrorRetry => _t('network_error_retry');
  String get setup => _t('setup');
  String get checkingSystemStatus => _t('checking_system_status');
  String get alreadySetUp => _t('already_set_up');
  String get alreadyInitialized => _t('already_initialized');
  String get goToAdminConsole => _t('go_to_admin_console');
  String get setupUnavailableTitle => _t('setup_unavailable_title');
  String get setupNotAvailable => _t('setup_not_available');
  String get administratorUsername => _t('administrator_username');
  String get clientId => _t('client_id');
  String get clientSecret => _t('client_secret');
  String get setupComplete => _t('setup_complete');
  String get setupCompleteDescription => _t('setup_complete_description');
  String get setupApplicationMissing => _t('setup_application_missing');
  String get retryApplicationCreation => _t('retry_application_creation');
  String get secretSavedConfirmation => _t('secret_saved_confirmation');
  String get secretEraseWarning => _t('secret_erase_warning');
  String get enterUsername => _t('enter_username');
  String get passwordMinimum => _t('password_minimum');
  String get passwordsMismatch => _t('passwords_mismatch');
  String get appNameOrSkip => _t('app_name_or_skip');
  String get redirectUriInvalid => _t('redirect_uri_invalid');
  String stepOf(int current, int total) =>
      '${_t('step')} $current ${_t('of')} $total';
  String shownOnce(String label) => '$label · ${_t('shown_once')}';
  String copyLabel(String label) => '${_t('copy')} $label';
  String copiedLabel(String label) => '$label ${_t('copied')}';

  // Device authorization
  String get authorizeDevice => _t('authorize_device');
  String get deviceCodeInstruction => _t('device_code_instruction');
  String get deviceCode => _t('device_code');
  String get devicePreviewHint => _t('device_preview_hint');
  String get checkCode => _t('check_code');
  String get checking => _t('checking');
  String get approve => _t('approve');
  String get deny => _t('deny');
  String get signInAgain => _t('sign_in_again');
  String get approveDeviceTitle => _t('approve_device_title');
  String get denyDeviceTitle => _t('deny_device_title');
  String get approveDeviceDescription => _t('approve_device_description');
  String get denyDeviceDescription => _t('deny_device_description');
  String get deviceCodeIncomplete => _t('device_code_incomplete');
  String get deviceCodeVerified => _t('device_code_verified');
  String get deviceApprovalContextMissing =>
      _t('device_approval_context_missing');
  String get deviceAlreadyApproved => _t('device_already_approved');
  String get deviceAlreadyDenied => _t('device_already_denied');
  String get deviceCodeExpired => _t('device_code_expired');
  String get deviceCodeNotFound => _t('device_code_not_found');
  String get deviceAuthorizationDisabled => _t('device_authorization_disabled');
  String get deviceCodeCheckFailed => _t('device_code_check_failed');
  String get deviceApproved => _t('device_approved');
  String get deviceDenied => _t('device_denied');
  String get signInExpired => _t('sign_in_expired');
  String get deviceCodeInvalidExpired => _t('device_code_invalid_expired');
  String get requestFailedRetry => _t('request_failed_retry');
  String requestedScopes(String scopes) => '${_t('requested_scopes')}: $scopes';
}
