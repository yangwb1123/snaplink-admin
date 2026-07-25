import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'admin_route.dart';
import 'snaplink_admin_api.dart';
class TokenSecurityTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const TokenSecurityTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<TokenSecurityTab> createState() => _TokenSecurityTabState();
}
class _TokenSecurityTabState extends State<TokenSecurityTab> {
  final _subjectCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final Map<String, Map<String, dynamic>> _data = {};
  String? _error;
  bool _loading = true;
  bool _mutating = false;
  static const _paths = {
    'sessions': '/api/v1/admin/sessions',
    'tokens': '/api/v1/admin/tokens',
    'portfolio': '/api/v1/admin/tokens/portfolio',
    'expiring': '/api/v1/admin/tokens/expiring',
    'suspicious': '/api/v1/admin/tokens/suspicious',
  };
  static const _bulkRevokePath = '/api/v1/admin/tokens/bulk-revoke';
  bool get _supportsBulkRevoke => widget.capabilities.has('POST', _bulkRevokePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_bulkRevokePath);
  String _currentSection = 'all';
  static const _secDefs = [
    SectionDef('all', 'All', Icons.dashboard),
    SectionDef('portfolio', 'Portfolio', Icons.account_balance_wallet),
    SectionDef('suspicious', 'Anomalies', Icons.warning),
    SectionDef('sessions', 'Sessions', Icons.devices),
    SectionDef('subjects', 'Bearers', Icons.person),
    SectionDef('expiring', 'Expiring', Icons.timer),
    SectionDef('temp', 'Temp Token', Icons.key),
    SectionDef('revoke', 'Revoke', Icons.remove_circle),
  ];
  @override
  void initState() {
    super.initState();
    _handleRoute();
    final p = () { if (mounted) _handleRoute(); };
    web.window.addEventListener('popstate', p.toJS);
    _load();
  }
  @override
  void dispose() {
    _subjectCtrl.dispose();
    _clientCtrl.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait(
      _paths.entries.map((entry) async {
        try {
          return (
            key: entry.key,
            data: await widget.api.get(entry.value),
            error: null,
          );
        } catch (error) {
          return (key: entry.key, data: null, error: error);
        }
      }),
    );
    if (!mounted) return;
    final unavailable = results
        .where((result) => result.error != null)
        .map((result) => result.key)
        .join(', ');
    setState(() {
      _data
        ..clear()
        ..addEntries([
          for (final result in results)
            if (result.data != null) MapEntry(result.key, result.data!),
        ]);
      _error = unavailable.isEmpty
          ? null
          : 'Some token data is unavailable: $unavailable.';
      _loading = false;
    });
  }
  List<Map<String, dynamic>> _list(String key, String valueKey) {
    final values = _data[key]?[valueKey];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }
  Future<void> _revokeAdminToken(String id) async {
    if (!await _confirm(
      'Revoke administrator token?',
      'The selected administrator session will immediately lose access.',
    )) {
      return;
    }
    await _write(
      () =>
          widget.api.delete('/api/v1/admin/tokens/${Uri.encodeComponent(id)}'),
      'Administrator token revoked.',
    );
  }
  Future<void> _bulkRevoke() async {
    final subject = _subjectCtrl.text.trim();
    final clientId = _clientCtrl.text.trim();
    if (subject.isEmpty && clientId.isEmpty) {
      setState(
        () =>
            _error = 'Set a subject and/or client ID to bound the revocation.',
      );
      return;
    }
    if (!await _confirm(
      'Bulk revoke refresh tokens?',
      'Refresh tokens in the supplied scope will be invalidated. Existing stateless access tokens expire naturally.',
    )) {
      return;
    }
    await _write(
      () => widget.api.post('/api/v1/admin/tokens/bulk-revoke', {
        if (subject.isNotEmpty) 'subject': subject,
        if (clientId.isNotEmpty) 'client_id': clientId,
        'confirm': true,
      }),
      'Refresh-token revocation completed.',
    );
  }
  Future<void> _write(
    Future<Map<String, dynamic>> Function() request,
    String message,
  ) async {
    setState(() => _mutating = true);
    try {
      await request();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Row(
          children: [
            Text(
              'Token and session security',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SectionSelector(sections: _secDefs, current: _currentSection, onSelected: _selectSection),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading) ...[
          if (_data.containsKey('portfolio')) _portfolioCard(context),
          if (_data.containsKey('suspicious')) _findingsCard(context),
          if (_data.containsKey('sessions')) _sessionsCard(context),
          if (_data.containsKey('tokens')) _adminTokensCard(context),
          if (_data.containsKey('expiring')) _expiringCard(context),
          if (_supportsBulkRevoke) _bulkRevokeCard(context),
          if (_supportsBulkRevoke) _tempTokenCard(context),
          if (_supportsBulkRevoke) _revokeTokenCard(context),
        ],
      ],
    );
  }
  bool _showSection(String section) => _currentSection == 'all' || _currentSection == section;
  Widget _portfolioCard(BuildContext context) {
    final portfolio = _data['portfolio']?['portfolio'] as Map? ?? const {};
    return _card(context, 'Token portfolio', [
      _metric('Issued', portfolio['issued_total']),
      _metric('Introspections', portfolio['introspections']),
      _metric('Userinfo calls', portfolio['userinfo']),
    ]);
  }
  Widget _findingsCard(BuildContext context) {
    final findings = _list('suspicious', 'findings');
    return _card(context, 'Detected token anomalies', [
      if (findings.isEmpty) const Text('No anomaly findings.'),
      for (final finding in findings)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            finding['severity'] == 'critical'
                ? Icons.warning_amber
                : Icons.info_outline,
            color: finding['severity'] == 'critical'
                ? Colors.redAccent
                : Colors.orangeAccent,
          ),
          title: Text(
            '${finding['type'] ?? 'finding'} · ${finding['subject_id'] ?? ''}',
          ),
          subtitle: Text(finding['detail']?.toString() ?? ''),
        ),
    ]);
  }
  Widget _sessionsCard(BuildContext context) {
    final sessions = _list('sessions', 'sessions');
    return _card(context, 'Active sessions', [
      Text('Total: ${_data['sessions']?['total'] ?? sessions.length}'),
      for (final session in sessions.take(100))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(session['id']?.toString() ?? ''),
          subtitle: Text(
            '${session['user_id'] ?? session['userId'] ?? ''} · ${session['ip'] ?? ''}',
          ),
        ),
    ]);
  }
  Widget _adminTokensCard(BuildContext context) {
    final tokens = _list('tokens', 'tokens');
    return _card(context, 'Administrator bearer tokens', [
      if (tokens.isEmpty) const Text('No administrator tokens found.'),
      for (final token in tokens)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            token['label']?.toString() ?? token['id']?.toString() ?? '',
          ),
          subtitle: Text(
            '${token['admin_id'] ?? ''} · ${(token['scopes'] as List? ?? const []).join(' ')}',
          ),
          trailing: TextButton(
            onPressed: _mutating
                ? null
                : () => _revokeAdminToken(token['id']?.toString() ?? ''),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Revoke'),
          ),
        ),
    ]);
  }
  Widget _expiringCard(BuildContext context) {
    final tokens = _list('expiring', 'tokens');
    return _card(context, 'Refresh tokens expiring soon', [
      if (tokens.isEmpty) const Text('No refresh-token expiry records.'),
      for (final token in tokens)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(token['subject']?.toString() ?? ''),
          subtitle: Text(
            '${token['client_id'] ?? ''} · ${token['expires_at'] ?? ''}',
          ),
        ),
    ]);
  }
  Widget _bulkRevokeCard(
    BuildContext context,
  ) => _card(context, 'Bounded refresh-token revocation', [
    const Text(
      'Supply at least one boundary. Snaplink rejects an unscoped revoke and may require confirmation for large batches.',
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _subjectCtrl,
      decoration: const InputDecoration(labelText: 'Subject (optional)'),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: _clientCtrl,
      decoration: const InputDecoration(labelText: 'Client ID (optional)'),
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      onPressed: _mutating ? null : _bulkRevoke,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
      ),
      child: const Text('Bulk revoke refresh tokens'),
    ),
  ]);
  Widget _metric(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text('$label: ${value ?? 0}'),
  );
  Widget _card(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(top: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
  final _createSubjectCtrl = TextEditingController();
  final _createScopesCtrl = TextEditingController(text: 'openid profile');
  final _revokeTokenCtrl = TextEditingController(); String? _tempToken;
  Future<void> _createTempToken() async {
    final subject = _createSubjectCtrl.text.trim();
    if (subject.isEmpty) { setState(() => _error = 'Subject is required.'); return; }
    setState(() { _mutating = true; _error = null; _tempToken = null; });
    try {
      final data = await widget.api.post('/api/v1/admin/tokens/temp', {
        'subject': subject,
        'scopes': _createScopesCtrl.text.split(' ').where((s) => s.isNotEmpty).toList(),
      });
      if (!mounted) return;
      final t = data['token']?.toString() ?? data['access_token']?.toString() ?? '';
      setState(() { _tempToken = t; });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
  Future<void> _revokeToken() async {
    final tokenId = _revokeTokenCtrl.text.trim();
    if (tokenId.isEmpty) { setState(() => _error = 'Enter a token ID.'); return; }
    final confirmed = await _confirm('Revoke token?', 'Revoke token $tokenId? This is immediate.');
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.post('/api/v1/admin/tokens/revoke', {'token_id': tokenId});
      if (!mounted) return;
      _revokeTokenCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token revoked.')));
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'token-security') return;
    final section = route.subresource.isNotEmpty ? route.subresource : 'all';
    if (_secDefs.any((s) => s.id == section)) {
      setState(() => _currentSection = section);
    }
  }
  void _selectSection(String section) {
    setState(() => _currentSection = section);
    if (section == 'all') {
      AdminRoute.go('token-security');
    } else {
      AdminRoute.go('token-security', subresource: section);
    }
  }
  Widget _tempTokenCard(BuildContext context) => _card(context, 'Create temporary token', [
    TextField(controller: _createSubjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
    const SizedBox(height: 10),
    TextField(controller: _createScopesCtrl, decoration: const InputDecoration(labelText: 'Scopes (space-separated)')),
    const SizedBox(height: 10),
    FilledButton(onPressed: _mutating ? null : _createTempToken, child: const Text('Create temp token')),
    if (_tempToken != null) ...[
      const SizedBox(height: 8),
      const Text('Save this token now. It will not be shown again.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
      SelectableText(_tempToken!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    ],
  ]);
  Widget _revokeTokenCard(BuildContext context) => _card(context, 'Revoke token by ID', [
    TextField(controller: _revokeTokenCtrl, decoration: const InputDecoration(labelText: 'Token ID')),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: _mutating ? null : _revokeToken,
      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
      child: const Text('Revoke token'),
    ),
  ]);
}