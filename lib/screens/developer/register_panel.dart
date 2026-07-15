import 'package:flutter/material.dart';
import 'developer_api.dart';

/// "Register a New App" tab: RFC 7591 Dynamic Client Registration form.
/// POSTs to /register — unauthenticated unless the developer supplies an
/// operator-issued initial access token — and on success displays the
/// ONE-TIME client_secret / registration_access_token the server returns
/// (never shown again, so the developer must copy them now).
class RegisterPanel extends StatefulWidget {
  final DeveloperApi api;
  final void Function(String clientId, String token) onManage;

  const RegisterPanel({super.key, required this.api, required this.onManage});

  @override
  State<RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends State<RegisterPanel> {
  final _nameCtrl = TextEditingController();
  final _redirectUrisCtrl = TextEditingController();
  final _scopeCtrl = TextEditingController();
  final _iatCtrl = TextEditingController();
  String _authMethod = 'client_secret_basic';
  String _tokenStrategy = 'jwt';
  bool _submitting = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _redirectUrisCtrl.dispose();
    _scopeCtrl.dispose();
    _iatCtrl.dispose();
    super.dispose();
  }

  List<String> _splitLines(String s) =>
      s.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await widget.api.register(
        clientName: _nameCtrl.text.trim(),
        redirectUris: _splitLines(_redirectUrisCtrl.text),
        scope: _scopeCtrl.text.trim(),
        tokenEndpointAuthMethod: _authMethod,
        tokenStrategy: _tokenStrategy,
        initialAccessToken: _iatCtrl.text.trim().isEmpty
            ? null
            : _iatCtrl.text.trim(),
      );
      if (mounted) setState(() => _result = result);
    } on DeveloperApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        'Register a new OAuth 2.0 / OIDC client application. '
                        'On success you receive a ',
                  ),
                  TextSpan(
                    text: 'client_id',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  TextSpan(text: ' (and, for confidential clients, a '),
                  TextSpan(
                    text: 'client_secret',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  TextSpan(
                    text:
                        ') plus a registration access token — the credential '
                        'this portal\'s Manage tab uses to view or update '
                        'your app later. ',
                  ),
                  TextSpan(
                    text:
                        'The secret and access token are shown ONCE and '
                        'never again — save them immediately.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'App Name',
                    hintText: 'My App',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _redirectUrisCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Redirect URIs (one per line)',
                    hintText: 'https://myapp.example.com/callback',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _scopeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Scope (space-separated)',
                    hintText: 'openid profile email',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _authMethod,
                  decoration: const InputDecoration(labelText: 'Client Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'client_secret_basic',
                      child: Text('Confidential (issues a client_secret)'),
                    ),
                    DropdownMenuItem(
                      value: 'none',
                      child: Text(
                        'Public (no secret — PKCE required, e.g. a SPA or mobile app)',
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _authMethod = v ?? _authMethod),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _tokenStrategy,
                  decoration: const InputDecoration(
                    labelText: 'Token Strategy',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'jwt', child: Text('jwt')),
                    DropdownMenuItem(value: 'session', child: Text('session')),
                  ],
                  onChanged: (v) =>
                      setState(() => _tokenStrategy = v ?? _tokenStrategy),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _iatCtrl,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText:
                        'Initial Access Token (only if your operator requires one)',
                    hintText: 'Leave blank if registration is open',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register App'),
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          _RegisterResultCard(result: _result!, onManage: widget.onManage),
        ],
      ],
    );
  }
}

class _RegisterResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final void Function(String clientId, String token) onManage;

  const _RegisterResultCard({required this.result, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final clientId = result['client_id']?.toString() ?? '';
    final clientSecret = result['client_secret']?.toString();
    final regToken = result['registration_access_token']?.toString();
    final regUri = result['registration_client_uri']?.toString();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF6366F1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SAVE THESE NOW — THEY WILL NOT BE SHOWN AGAIN',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: const Color(0xFF6366F1)),
            ),
            const SizedBox(height: 14),
            _kvRow('Client ID', clientId),
            if (clientSecret != null) _kvRow('Client Secret', clientSecret),
            if (regToken != null) _kvRow('Registration Access Token', regToken),
            if (regUri != null) _kvRow('Registration Client URI', regUri),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onManage(clientId, regToken ?? ''),
              child: const Text('Manage This App'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
