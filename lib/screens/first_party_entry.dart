import 'package:flutter/material.dart';
import 'admin/dashboard_screen.dart';
import 'oidc_login/oidc_login_screen.dart';
import '../sso_client.dart';

enum _Stage { login, probing, dashboard, noAdminAccess }

/// Wraps OidcLoginScreen for first-party (non-RP) access — both /login/ and
/// /admin/ route here. On successful login, probes whether the resulting
/// token has admin API access (reusing the exact request the dashboard
/// itself would make, rather than parsing JWT claims or coupling to the
/// permissions schema) and routes accordingly: DashboardScreen when allowed,
/// a plain "signed in, no admin access" message otherwise. This is how admin
/// and regular accounts share ONE login screen and diverge purely by what
/// the admin API allows for that account, not by a separate admin login form.
class FirstPartyLoginScreen extends StatefulWidget {
  const FirstPartyLoginScreen({super.key});

  @override
  State<FirstPartyLoginScreen> createState() => _FirstPartyLoginScreenState();
}

class _FirstPartyLoginScreenState extends State<FirstPartyLoginScreen> {
  _Stage _stage = _Stage.login;
  SSOAdminClient? _client;
  String? _probeError;

  Future<void> _onLoggedIn(String accessToken) async {
    setState(() => _stage = _Stage.probing);
    final client = SSOAdminClient.withToken(accessToken);
    try {
      await client.listClients();
      if (!mounted) return;
      setState(() {
        _client = client;
        _stage = _Stage.dashboard;
      });
    } on SSOError catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.noAdminAccess;
        _probeError = e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.noAdminAccess;
        _probeError = 'Network error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.login:
        return OidcLoginScreen(
          defaultClientId: 'sso-admin-console',
          onFirstPartySuccess: _onLoggedIn,
        );
      case _Stage.probing:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Stage.dashboard:
        return DashboardScreen(client: _client!);
      case _Stage.noAdminAccess:
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Signed in', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 10),
                        const Text('This account does not have admin access.'),
                        if (_probeError != null) ...[
                          const SizedBox(height: 8),
                          Text(_probeError!, style: const TextStyle(color: Colors.redAccent)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => setState(() {
                            _stage = _Stage.login;
                            _client = null;
                            _probeError = null;
                          }),
                          child: const Text('Back to sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }
}
