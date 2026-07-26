import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'package:web/web.dart' as web;

/// User detail screen with sub-resource tabs.
/// URL: /admin/users/{id}[/{subresource}]
class UserDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String userId;

  const UserDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.userId,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _sessions;
  Map<String, dynamic>? _consents;
  Map<String, dynamic>? _mfa;
  Map<String, dynamic>? _lifecycle;
  String? _error;
  bool _loading = true;
  bool _mutating = false;
  int _tabIndex = 0;

  static const _tabs = [
    ('sessions', 'Sessions', Icons.devices),
    ('consents', 'Consents', Icons.checklist),
    ('mfa', 'MFA', Icons.security),
    ('lifecycle', 'Lifecycle', Icons.route),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _initTabFromRoute();
    void popListener() { if (mounted) _initTabFromRoute(); }
    web.window.addEventListener('popstate', popListener.toJS);
  }

  void _initTabFromRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.resourceId != widget.userId) return;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) {
        setState(() => _tabIndex = i);
        return;
      }
    }
  }

  void _selectTab(int index, String subresource) {
    setState(() => _tabIndex = index);
    AdminRoute.go('users', resourceId: widget.userId, subresource: subresource);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.client.getUser(widget.userId),
        widget.api.get('/api/v1/admin/users/${Uri.encodeComponent(widget.userId)}/sessions'),
        widget.api.get('/api/v1/admin/users/${Uri.encodeComponent(widget.userId)}/consents'),
        widget.api.get('/api/v1/admin/users/${Uri.encodeComponent(widget.userId)}/mfa'),
        widget.api.get('/api/v1/admin/users/${Uri.encodeComponent(widget.userId)}/lifecycle'),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as Map<String, dynamic>?;
        _sessions = results[1] as Map<String, dynamic>?;
        _consents = results[2] as Map<String, dynamic>?;
        _mfa = results[3] as Map<String, dynamic>?;
        _lifecycle = results[4] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User: ${widget.userId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AdminRoute.go('users'),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Failed to load user', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_error!, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(children: [
              AdminBreadcrumb(),
              Expanded(child: _buildContent(context)),
            ]),
    );
  }

  Widget _buildContent(BuildContext context) => Column(
    children: [
      _userHeader(context),
      _tabBar(context),
      Expanded(child: _tabContent(context)),
    ],
  );

  Widget _userHeader(BuildContext context) => Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Icon(Icons.person, size: 48),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_user?['id']?.toString() ?? '', style: Theme.of(context).textTheme.titleMedium),
            Text('Provider: ${_user?['provider'] ?? ''}'),
            Text('External ID: ${_user?['externalId'] ?? _user?['external_id'] ?? ''}'),
          ],
        )),
      ]),
    ),
  );

  Widget _tabBar(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_tabs[i].$2),
              selected: _tabIndex == i,
              onSelected: (_) => _selectTab(i, _tabs[i].$1),
            ),
          ),
      ],
    ),
  );

  Widget _tabContent(BuildContext context) {
    switch (_tabIndex) {
      case 0: return _sessionList(context);
      case 1: return _consentList(context);
      case 2: return _mfaList(context);
      case 3: return _lifecycleView(context);
      default: return const Center(child: Text('Select a tab'));
    }
  }

  Widget _sessionList(BuildContext context) {
    final items = _sessions?['sessions'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
        ? [const Text('No active sessions')]
        : items.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.devices),
              title: Text(s['id']?.toString() ?? ''),
              subtitle: Text('IP: ${s['ip'] ?? ''}  UA: ${(s['user_agent'] ?? '').toString().substring(0, (s['user_agent']?.toString() ?? '').length.clamp(0, 80))}'),
            ),
          )).toList(),
    );
  }

  Widget _consentList(BuildContext context) {
    final items = _consents?['consents'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
        ? [const Text('No consents granted')]
        : items.map((c) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.checklist),
              title: Text(c['client_id']?.toString() ?? ''),
              subtitle: Text((c['scopes'] as List?)?.join(', ') ?? ''),
              trailing: TextButton(
                onPressed: _mutating ? null : () => _revokeConsent(c['client_id']?.toString() ?? ''),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Revoke'),
              ),
            ),
          )).toList(),
    );
  }

  Future<void> _revokeConsent(String clientId) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Revoke consent?', message: 'Revoke for $clientId?', destructive: true);
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete('/api/v1/admin/users/${Uri.encodeComponent(widget.userId)}/consents/${Uri.encodeComponent(clientId)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consent revoked')));
      _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: \$e"))); }
    finally { if (mounted) setState(() => _mutating = false); }
  }

  Widget _mfaList(BuildContext context) {
    final items = _mfa?['factors'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
        ? [const Text('No MFA factors registered')]
        : items.map((f) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.security),
              title: Text(f['label']?.toString() ?? f['method']?.toString() ?? ''),
              subtitle: Text('Method: ${f['method'] ?? ''}'),
              trailing: TextButton(
                onPressed: _mutating ? null : () => _removeMfa(f['id']?.toString() ?? ''),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Remove'),
              ),
            ),
          )).toList(),
    );
  }

  Future<void> _removeMfa(String factorId) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Remove MFA factor?', message: 'Remove this factor?', destructive: true);
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete('/api/v1/admin/users/${Uri.encodeComponent(widget.userId)}/mfa/${Uri.encodeComponent(factorId)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MFA factor removed')));
      _load();
    } catch (_) {}
    finally { if (mounted) setState(() => _mutating = false); }
  }

  Widget _lifecycleView(BuildContext context) {
    final lc = _lifecycle ?? {};
    final state = lc['state']?.toString() ?? 'active';
    final transitions = (lc['allowed_transitions'] as List?)?.map((e) => e.toString()).toList() ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Icon(Icons.route, size: 48, color: Colors.blue),
            const SizedBox(height: 8),
            Text('Current state: $state', style: Theme.of(context).textTheme.titleMedium),
            if (transitions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Allowed transitions:'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: transitions.map((t) => Chip(label: Text(t))).toList()),
            ],
          ]),
        )),
        if (_user != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => AdminRoute.go('users'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to user list'),
          ),
        ],
      ],
    );
  }
}
