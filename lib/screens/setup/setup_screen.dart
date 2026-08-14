import 'package:flutter/material.dart';

import '../../i18n/app_strings.dart';
import '../../services/browser_navigation.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/responsive_entry_card.dart';
import 'setup_api.dart';
import 'setup_validation.dart';
import 'setup_widgets.dart';

/// Mirrors the five views of interfaces/web/setup/{index.html,app.js}:
/// loading -> (alreadyInitialized | admin -> app -> done).
enum _Step { loading, unavailable, alreadyInitialized, admin, app, done }

/// First-run setup wizard: checks `GET /api/v1/setup/status` and, if the
/// deployment is fresh, walks the operator through creating the first admin
/// account and (optionally) a first OAuth client via a single
/// `POST /api/v1/setup`. Faithful port of interfaces/web/setup/app.js.
class SetupScreen extends StatefulWidget {
  final SetupApi? api;

  const SetupScreen({super.key, this.api});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final SetupApi _api = widget.api ?? SetupApi();
  _Step _step = _Step.loading;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();
  final _appNameCtrl = TextEditingController();
  final _appRedirectCtrl = TextEditingController();
  String? _adminError;
  String? _appError;
  String? _unavailableMessage;
  bool _submitting = false;
  // Captured at the end of step 1, POSTed once together with the optional
  // application at the end of step 2 — app.js keeps this in a single
  // module-level `admin` variable and does one fetch, in `finish()`.
  SetupAdmin? _pendingAdmin;
  String? _createdAdminName;
  String? _createdClientId;
  String? _createdClientSecret;
  SetupApplication? _recoveryApplication;
  bool _requestedApplicationMissing = false;
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    _appNameCtrl.dispose();
    _appRedirectCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _step = _Step.loading;
      _unavailableMessage = null;
    });
    try {
      final status = await _api.checkStatus();
      if (!mounted) return;
      setState(() {
        _step = !status.available
            ? _Step.unavailable
            : (status.setupRequired ? _Step.admin : _Step.alreadyInitialized);
        if (!status.available) {
          _unavailableMessage = AppStrings.of(context).setupUnavailable;
        }
      });
    } on SetupNetworkError {
      if (mounted) {
        setState(() {
          _step = _Step.unavailable;
          _unavailableMessage = AppStrings.of(context).setupStatusUnknown;
        });
      }
    }
  }

  // Step 1: client-side validation only (no network call) — identical
  // ordering to app.js's admin-form submit handler.
  void _continueFromAdminStep() {
    final strings = AppStrings.of(context);
    setState(() => _adminError = null);
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    final p2 = _password2Ctrl.text;
    if (u.isEmpty) {
      setState(() => _adminError = strings.enterUsername);
      return;
    }
    if (p.length < 8) {
      setState(() => _adminError = strings.passwordMinimum);
      return;
    }
    if (p != p2) {
      setState(() => _adminError = strings.passwordsMismatch);
      return;
    }
    _pendingAdmin = SetupAdmin(username: u, password: p);
    setState(() => _step = _Step.app);
  }

  Future<void> _submitAppStep() async {
    final strings = AppStrings.of(context);
    final name = _appNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _appError = strings.appNameOrSkip);
      return;
    }
    late final List<String> redirects;
    try {
      redirects = parseSetupRedirectUris(
        _appRedirectCtrl.text,
        invalidMessage: strings.redirectUriInvalid,
      );
    } on FormatException catch (error) {
      setState(() => _appError = error.message);
      return;
    }
    await _finish(SetupApplication(name: name, redirectUris: redirects));
  }

  Future<void> _skip() => _finish(null);
  Future<void> _finish(SetupApplication? application) async {
    setState(() {
      _appError = null;
      _submitting = true;
    });
    try {
      final result = await _api.submit(
        admin: _pendingAdmin!,
        application: application,
      );
      if (!mounted) return;
      if (result.alreadyInitialized) {
        setState(() => _step = _Step.alreadyInitialized);
        return;
      }
      if (result.error != null) {
        setState(() => _appError = result.error);
        return;
      }
      setState(() {
        _createdAdminName = result.createdAdmin;
        _createdClientId = result.clientId;
        _createdClientSecret = result.clientSecret;
        _recoveryApplication = result.recoveryApplication;
        _requestedApplicationMissing = result.recoveryApplication != null;
        _step = _Step.done;
      });
    } on SetupNetworkError {
      if (!mounted) return;
      setState(() => _appError = AppStrings.of(context).networkErrorRetry);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // The JS's "Go to admin console" is a plain `<a href="../admin/">` — a
  // real navigation, matching every other transition in the unified auth
  // flow (AdminGateScreen will redirect to /login/ itself, since there's no
  // session yet right after setup completes).
  void _goToAdminConsole() {
    BrowserNavigation.assignLocation('/admin/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveEntryCard(maxWidth: 460, child: _buildStep(context)),
    );
  }

  Widget _buildStep(BuildContext context) {
    final strings = AppStrings.of(context);
    switch (_step) {
      case _Step.loading:
        return const SetupLoadingPanel();
      case _Step.unavailable:
        return SetupUnavailablePanel(
          message: _unavailableMessage ?? strings.setupNotAvailable,
          onRetry: _checkStatus,
          onContinue: _goToAdminConsole,
        );
      case _Step.alreadyInitialized:
        return SetupAlreadyInitializedPanel(onContinue: _goToAdminConsole);
      case _Step.admin:
        return _buildAdminForm(context);
      case _Step.app:
        return _buildAppForm(context);
      case _Step.done:
        return _buildDone(context);
    }
  }

  Widget _buildAdminForm(BuildContext context) {
    final strings = AppStrings.of(context);
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SetupLogo(),
          const SizedBox(height: 12),
          SetupStepDots(activeCount: 1),
          const SizedBox(height: 16),
          Text(
            strings.createAdministrator,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.createAdministratorDescription,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_adminError != null) ...[
            SetupInlineNotice(text: _adminError!),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _usernameCtrl,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            autofillHints: const [AutofillHints.newUsername],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: strings.adminUsername,
              hintText: 'admin',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: strings.password,
              hintText: context.tr('at least 8 characters'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password2Ctrl,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: strings.confirmPassword),
            onSubmitted: (_) => _continueFromAdminStep(),
          ),
          const SizedBox(height: 20),
          PressableScale(
            child: FilledButton(
              onPressed: _continueFromAdminStep,
              child: Text(strings.continueLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppForm(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        SetupStepDots(activeCount: 2),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              strings.firstApplication,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SetupOptionalTag(label: strings.optional),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          strings.firstApplicationDescription,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_appError != null) ...[
          SetupInlineNotice(text: _appError!),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _appNameCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: strings.applicationName,
            hintText: context.tr('My App'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _appRedirectCtrl,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: strings.redirectUris,
            hintText: strings.oneHttpsUriPerLine,
          ),
          minLines: 2,
          maxLines: 5,
        ),
        const SizedBox(height: 20),
        PressableScale(
          child: FilledButton(
            onPressed: _submitting ? null : _submitAppStep,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.createAndFinish),
          ),
        ),
        const SizedBox(height: 12),
        PressableScale(
          child: OutlinedButton(
            onPressed: _submitting ? null : _skip,
            child: Text(strings.skipAndFinish),
          ),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) => SetupDonePanel(
    adminUsername: _createdAdminName,
    clientId: _createdClientId,
    clientSecret: _createdClientSecret,
    applicationRequestedButMissing: _requestedApplicationMissing,
    onRetryApplication: _recoveryApplication == null
        ? null
        : () => _finish(_recoveryApplication),
    busy: _submitting,
    onDone: () => BrowserNavigation.replaceLocation('/admin/'),
  );
}
