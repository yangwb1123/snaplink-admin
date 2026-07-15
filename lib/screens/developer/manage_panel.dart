import 'package:flutter/material.dart';
import 'developer_api.dart';

/// "Manage an Existing App" tab: RFC 7592 read/update/delete of an
/// already-registered client, authenticated solely by the
/// registration_access_token returned at registration time — there is no
/// developer login/account here.
///
/// The State class is public (not `_ManagePanelState`) so [DeveloperScreen]
/// can hold a `GlobalKey<ManagePanelState>` and drive [loadWith] directly
/// after a fresh registration, without re-plumbing shared state through
/// the TabBarView.
class ManagePanel extends StatefulWidget {
  final DeveloperApi api;
  const ManagePanel({super.key, required this.api});

  @override
  State<ManagePanel> createState() => ManagePanelState();
}

class ManagePanelState extends State<ManagePanel> {
  final _clientIdCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _redirectUrisCtrl = TextEditingController();
  final _scopeCtrl = TextEditingController();
  String _tokenStrategy = 'jwt';

  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  // Holds the full last-GET RFC 7592 representation behind the loaded app —
  // PUT must round-trip every field this form does NOT expose (grant_types,
  // response_types, allowed_authenticators, allowed_resources,
  // post_logout_redirect_uris, ...) UNCHANGED, since the server takes those
  // verbatim from the request with no stored-value fallback. Dropping them
  // would silently wipe real client capabilities on every save.
  Map<String, dynamic>? _currentApp;

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _tokenCtrl.dispose();
    _nameCtrl.dispose();
    _redirectUrisCtrl.dispose();
    _scopeCtrl.dispose();
    super.dispose();
  }

  /// Called by DeveloperScreen right after a fresh registration + "Manage
  /// This App" so the developer doesn't have to retype what was just
  /// issued.
  void loadWith(String clientId, String token) {
    _clientIdCtrl.text = clientId;
    _tokenCtrl.text = token;
    _load();
  }

  List<String> _splitLines(String s) =>
      s.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  void _populateForm(Map<String, dynamic> d) {
    _nameCtrl.text = (d['client_name'] as String?) ?? '';
    final uris = (d['redirect_uris'] as List?) ?? const [];
    _redirectUrisCtrl.text = uris.join('\n');
    _scopeCtrl.text = (d['scope'] as String?) ?? '';
    _tokenStrategy = (d['token_strategy'] as String?) ?? 'jwt';
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final clientId = _clientIdCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    if (clientId.isEmpty || token.isEmpty) {
      setState(
        () => _loadError =
            'Client ID and registration access token are both required.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final app = await widget.api.loadApp(clientId: clientId, token: token);
      setState(() {
        _currentApp = app;
        _populateForm(app);
      });
    } catch (_) {
      // The server collapses every failure (wrong token, unknown
      // client_id) to the same 401 shape by design (anti-enumeration) —
      // never surface the underlying detail here, only this fixed message.
      setState(() {
        _currentApp = null;
        _loadError = 'Invalid client ID or registration access token.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final current = _currentApp;
    if (current == null) return;
    final clientId = _clientIdCtrl.text.trim();
    final token = _tokenCtrl.text.trim();

    final body = Map<String, dynamic>.from(current);
    body.remove('client_id');
    body.remove('client_secret');
    body.remove('client_id_issued_at');
    body.remove('client_secret_expires_at');
    body.remove('registration_access_token');
    body.remove('registration_client_uri');
    body['client_name'] = _nameCtrl.text.trim();
    body['redirect_uris'] = _splitLines(_redirectUrisCtrl.text);
    body['scope'] = _scopeCtrl.text.trim();
    body['token_strategy'] = _tokenStrategy;

    setState(() => _saving = true);
    try {
      final updated = await widget.api.saveApp(
        clientId: clientId,
        token: token,
        body: body,
      );
      setState(() {
        _currentApp = updated;
        _populateForm(updated);
        // A rotated registration_access_token (only when the operator
        // enabled rotate_access_token) invalidates the one just used to
        // authenticate THIS save — swap it in so the next save/delete
        // still works.
        final rotated = updated['registration_access_token'] as String?;
        if (rotated != null && rotated.isNotEmpty) {
          _tokenCtrl.text = rotated;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
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
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final current = _currentApp;
    if (current == null) return;
    final clientId = _clientIdCtrl.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete app?'),
        content: Text('Delete this app ($clientId)? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _delete();
  }

  Future<void> _delete() async {
    final clientId = _clientIdCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    try {
      await widget.api.deleteApp(clientId: clientId, token: token);
      setState(() {
        _currentApp = null;
        _clientIdCtrl.clear();
        _tokenCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App deleted.')));
      }
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _clientIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Client ID',
                    hintText: 'client id',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Registration Access Token',
                    hintText: 'registration access token',
                  ),
                ),
                if (_loadError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _loadError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _load,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load App'),
                ),
              ],
            ),
          ),
        ),
        if (_currentApp != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'APP CONFIGURATION',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'App Name'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _redirectUrisCtrl,
                    maxLines: 3,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Redirect URIs (one per line)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _scopeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Scope (space-separated)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _tokenStrategy,
                    decoration: const InputDecoration(
                      labelText: 'Token Strategy',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'jwt', child: Text('jwt')),
                      DropdownMenuItem(
                        value: 'session',
                        child: Text('session'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _tokenStrategy = v ?? _tokenStrategy),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        child: const Text('Delete App'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
