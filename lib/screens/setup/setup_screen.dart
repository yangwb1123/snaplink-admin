import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'setup_api.dart';
import 'setup_widgets.dart';
/// Mirrors the five views of interfaces/web/setup/{index.html,app.js}:
/// loading -> (alreadyInitialized | admin -> app -> done).
enum _Step { loading, unavailable, alreadyInitialized, admin, app, done }
/// First-run setup wizard: checks `GET /api/v1/setup/status` and, if the
/// deployment is fresh, walks the operator through creating the first admin
/// account and (optionally) a first OAuth client via a single
/// `POST /api/v1/setup`. Faithful port of interfaces/web/setup/app.js.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}
class _SetupScreenState extends State<SetupScreen> {
  final SetupApi _api = SetupApi();
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
          _unavailableMessage = 'The setup wizard is disabled on this server.';
        }
      });
    } on SetupNetworkError {
      if (mounted) {
        setState(() {
          _step = _Step.unavailable;
          _unavailableMessage =
              'Could not determine whether setup is available.';
        });
      }
    }
  }
  // Step 1: client-side validation only (no network call) — identical
  // ordering to app.js's admin-form submit handler.
  void _continueFromAdminStep() {
    setState(() => _adminError = null);
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    final p2 = _password2Ctrl.text;
    if (u.isEmpty) {
      setState(() => _adminError = 'Please enter a username.');
      return;
    }
    if (p.length < 8) {
      setState(() => _adminError = 'Password must be at least 8 characters.');
      return;
    }
    if (p != p2) {
      setState(() => _adminError = 'Passwords do not match.');
      return;
    }
    _pendingAdmin = SetupAdmin(username: u, password: p);
    setState(() => _step = _Step.app);
  }
  Future<void> _submitAppStep() async {
    final name = _appNameCtrl.text.trim();
    final redirect = _appRedirectCtrl.text.trim();
    if (name.isEmpty) {
      setState(
        () => _appError = 'Enter an application name, or use Skip and finish.',
      );
      return;
    }
    await _finish(
      SetupApplication(
        name: name,
        redirectUri: redirect.isEmpty ? null : redirect,
      ),
    );
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
        _step = _Step.done;
      });
    } on SetupNetworkError {
      if (!mounted) return;
      setState(() => _appError = 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
  // The JS's "Go to admin console" is a plain `<a href="../admin/">` — a
  // real navigation, matching every other transition in the unified auth
  // flow (AdminGateScreen will redirect to /login/ itself, since there's no
  // session yet right after setup completes).
  void _goToAdminConsole() {
    web.window.location.href = '/admin/';
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _buildStep(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case _Step.loading:
        return _buildLoading(context);
      case _Step.unavailable:
        return _buildUnavailable(context);
      case _Step.alreadyInitialized:
        return _buildAlready(context);
      case _Step.admin:
        return _buildAdminForm(context);
      case _Step.app:
        return _buildAppForm(context);
      case _Step.done:
        return _buildDone(context);
    }
  }
  Widget _buildLoading(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        Text(
          'Setup',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Checking system status…',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  Widget _buildAlready(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        Text(
          'Already set up',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        SetupSuccessBox(text: 'This system has already been initialized.'),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _goToAdminConsole,
          child: const Text('Go to admin console'),
        ),
      ],
    );
  }
  Widget _buildUnavailable(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        Text(
          'Setup unavailable',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        SetupErrorBox(text: _unavailableMessage ?? 'Setup is not available.'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _checkStatus, child: const Text('Retry')),
        FilledButton(
          onPressed: _goToAdminConsole,
          child: const Text('Go to admin console'),
        ),
      ],
    );
  }
  Widget _buildAdminForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        SetupStepDots(activeCount: 1),
        const SizedBox(height: 14),
        Text(
          'Create administrator',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'This first account gets full admin:* access. You can add more users later in the console.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        if (_adminError != null) ...[
          SetupErrorBox(text: _adminError!),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _usernameCtrl,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Admin username',
            hintText: 'admin',
          ),
          onSubmitted: (_) => _continueFromAdminStep(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'at least 8 characters',
          ),
          onSubmitted: (_) => _continueFromAdminStep(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password2Ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm password'),
          onSubmitted: (_) => _continueFromAdminStep(),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _continueFromAdminStep,
          child: const Text('Continue'),
        ),
      ],
    );
  }
  Widget _buildAppForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        SetupStepDots(activeCount: 2),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'First application',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 8),
            const SetupOptionalTag(),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Register a first OAuth/OIDC client now, or skip and add applications later in the console.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        if (_appError != null) ...[
          SetupErrorBox(text: _appError!),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _appNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Application name',
            hintText: 'My App',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _appRedirectCtrl,
          decoration: const InputDecoration(
            labelText: 'Redirect URI',
            hintText: 'https://app.example.com/callback',
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _submitting ? null : _submitAppStep,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create and finish'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : _skip,
                child: const Text('Skip and finish'),
              ),
            ),
          ],
        ),
      ],
    );
  }
    Widget _buildDone(BuildContext context) => SetupDonePanel(
    config: _createdAdminName != null ? {'issuer': _createdAdminName} : null, clientId: _createdClientId, clientSecret: _createdClientSecret,
    onDone: () => web.window.location.replace('/admin/'),
  );
}
