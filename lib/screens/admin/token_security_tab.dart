import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/count_up.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
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
  final _createUserCtrl = TextEditingController();
  final _createScopesCtrl = TextEditingController(text: 'openid profile');
  final _revokeTokenCtrl = TextEditingController();
  final Map<String, Map<String, dynamic>> _data = {};
  String? _error;
  bool _loading = true;
  bool _mutating = false;
  String? _tempToken;
  String _revokeKind = 'session_id';
  late final void Function() _cancelPopState;

  static const _paths = {
    'sessions': '/api/v1/admin/sessions',
    'tokens': '/api/v1/admin/tokens',
    'portfolio': '/api/v1/admin/tokens/portfolio',
    'expiring': '/api/v1/admin/tokens/expiring',
    'suspicious': '/api/v1/admin/tokens/suspicious',
  };
  static const _bulkRevokePath = '/api/v1/admin/tokens/bulk-revoke';
  static const _tempTokenPath = '/api/v1/admin/tokens/temp';
  static const _singleRevokePath = '/api/v1/admin/tokens/revoke';
  static const _adminTokenPath = '/api/v1/admin/tokens/:id';

  bool _supports(String method, String path) {
    final documentedPath = path.replaceAll('/:id', '/{id}');
    return widget.capabilities.has(method, path) ||
        SnaplinkAdminOperationCatalog.endpoints.any(
          (endpoint) =>
              endpoint.method == method && endpoint.path == documentedPath,
        );
  }

  bool get _supportsBulkRevoke => _supports('POST', _bulkRevokePath);
  bool get _supportsTempToken => _supports('POST', _tempTokenPath);
  bool get _supportsSingleRevoke => _supports('POST', _singleRevokePath);
  bool get _supportsAdminTokenRevoke => _supports('DELETE', _adminTokenPath);

  String _currentSection = 'all';
  static const _allSectionDefs = [
    SectionDef('all', 'All', Icons.dashboard),
    SectionDef('portfolio', 'Portfolio', Icons.account_balance_wallet),
    SectionDef('suspicious', 'Anomalies', Icons.warning),
    SectionDef('sessions', 'Sessions', Icons.devices),
    SectionDef('expiring', 'Expiring', Icons.timer),
    SectionDef('temp', 'Temp Token', Icons.key),
    SectionDef('revoke', 'Revoke', Icons.remove_circle),
  ];

  List<SectionDef> get _sectionDefs => [
    for (final section in _allSectionDefs)
      if (section.id == 'all' ||
          (section.id == 'portfolio' &&
              _supports('GET', _paths['portfolio']!)) ||
          (section.id == 'suspicious' &&
              _supports('GET', _paths['suspicious']!)) ||
          (section.id == 'sessions' && _supports('GET', _paths['sessions']!)) ||
          (section.id == 'expiring' && _supports('GET', _paths['expiring']!)) ||
          (section.id == 'temp' && _supportsTempToken) ||
          (section.id == 'revoke' &&
              (_supportsSingleRevoke ||
                  _supportsBulkRevoke ||
                  _supportsAdminTokenRevoke)))
        section,
  ];

  bool _shows(String section) =>
      _currentSection == 'all' || _currentSection == section;

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
    _load();
  }

  @override
  void dispose() {
    _tempToken = null;
    _revokeTokenCtrl.clear();
    _cancelPopState();
    _subjectCtrl.dispose();
    _clientCtrl.dispose();
    _createUserCtrl.dispose();
    _createScopesCtrl.dispose();
    _revokeTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    widget.api.skipCache();
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait(
      _paths.entries.where((entry) => _supports('GET', entry.value)).map((
        entry,
      ) async {
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
      ).showSnackBar(SnackBar(content: LocalizedText(message)));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<bool> _confirm(String title, String body, {String? confirmText}) =>
      ConfirmDialog.show(
        context,
        title: title,
        message: body,
        confirmLabel: 'Confirm',
        destructive: true,
        confirmText: confirmText,
      );
  @override
  Widget build(BuildContext context) {
    // 子菜单固定在最上面一行（非滚动区）——Material TabBar 模式。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminBreadcrumb(),
              Row(
                children: [
                  Text(
                    AppStrings.of(context).tokenSessionSecurity,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const LocalizedText(
                'Token issuance, lifetimes and rotation policies across clients.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: 8),
              SectionSelector(
                sections: _sectionDefs,
                current: _currentSection,
                onSelected: _selectSection,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LocalizedText(
              _error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading) ...[
          _securitySummary(context),
          if (_shows('portfolio') && _data.containsKey('portfolio'))
            _portfolioCard(context),
          if (_shows('suspicious') && _data.containsKey('suspicious'))
            _findingsCard(context),
          if (_shows('sessions') && _data.containsKey('sessions'))
            _sessionsCard(context),
          if (_shows('revoke') && _data.containsKey('tokens'))
            _adminTokensCard(context),
          if (_shows('expiring') && _data.containsKey('expiring'))
            _expiringCard(context),
          if (_shows('revoke') && _supportsBulkRevoke) _bulkRevokeCard(context),
          if (_shows('temp') && _supportsTempToken) _tempTokenCard(context),
          if (_shows('revoke') && _supportsSingleRevoke)
            _revokeTokenCard(context),
        ],
      ],
        ),
      ),
      ],
    );
  }

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
      if (findings.isEmpty) const LocalizedText('No anomaly findings.'),
      for (final finding in findings)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            finding['severity'] == 'critical'
                ? Icons.warning_amber
                : Icons.info_outline,
            color: finding['severity'] == 'critical'
                ? AppColors.danger
                : AppColors.warning,
          ),
          title: LocalizedText(
            '${finding['type'] ?? 'finding'} · ${finding['subject_id'] ?? ''}',
          ),
          subtitle: Text(finding['detail']?.toString() ?? ''),
        ),
    ]);
  }

  Widget _sessionsCard(BuildContext context) {
    final sessions = _list('sessions', 'sessions');
    return _card(context, 'Active sessions', [
      LocalizedText('Total: {total}', args: {'total': _data['sessions']?['total'] ?? sessions.length}),
      for (final session in sessions.take(100))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(session['id']?.toString() ?? ''),
          subtitle: LocalizedText(
            '${session['user_id'] ?? session['userId'] ?? ''} · ${session['ip'] ?? ''}',
          ),
        ),
    ]);
  }

  Widget _adminTokensCard(BuildContext context) {
    final tokens = _list('tokens', 'tokens');
    return _card(context, 'Administrator bearer tokens', [
      if (tokens.isEmpty) const LocalizedText('No administrator tokens found.'),
      for (final token in tokens)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            token['label']?.toString() ?? token['id']?.toString() ?? '',
          ),
          subtitle: LocalizedText(
            '${token['admin_id'] ?? ''} · ${(token['scopes'] as List? ?? const []).join(' ')}',
          ),
          trailing: _supportsAdminTokenRevoke
              ? TextButton(
                  onPressed: _mutating
                      ? null
                      : () => _revokeAdminToken(token['id']?.toString() ?? ''),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const LocalizedText('Revoke'),
                )
              : null,
        ),
    ]);
  }

  Widget _expiringCard(BuildContext context) {
    final tokens = _list('expiring', 'tokens');
    return _card(context, 'Refresh tokens expiring soon', [
      if (tokens.isEmpty)
        const LocalizedText('No refresh-token expiry records.'),
      for (final token in tokens)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(token['subject']?.toString() ?? ''),
          subtitle: LocalizedText(
            '${token['client_id'] ?? ''} · ${token['expires_at'] ?? ''}',
          ),
        ),
    ]);
  }

  Widget _bulkRevokeCard(
    BuildContext context,
  ) => _card(context, 'Bounded refresh-token revocation', [
    const LocalizedText(
      'Supply at least one boundary. Snaplink rejects an unscoped revoke and may require confirmation for large batches.',
    ),
    const SizedBox(height: 12),
    TextField(
      key: const Key('bulk-revoke-subject'),
      controller: _subjectCtrl,
      decoration: InputDecoration(labelText: 'Subject (optional)'.localized),
    ),
    const SizedBox(height: 12),
    TextField(
      key: const Key('bulk-revoke-client'),
      controller: _clientCtrl,
      decoration: InputDecoration(labelText: 'Client ID (optional)'.localized),
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      key: const Key('bulk-revoke-submit'),
      onPressed: _mutating ? null : _bulkRevoke,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      ),
      child: const LocalizedText('Bulk revoke refresh tokens'),
    ),
  ]);
  Widget _metric(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: LocalizedText('{label}: {value}', args: {'label': label, 'value': value ?? 0}),
  );
  Widget _card(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(top: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LocalizedText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
  Future<void> _createTempToken() async {
    final userId = _createUserCtrl.text.trim();
    if (userId.isEmpty) {
      setState(() => _error = 'User ID is required.');
      return;
    }
    final scopes = _createScopesCtrl.text
        .split(RegExp(r'\s+'))
        .where((scope) => scope.isNotEmpty)
        .toList(growable: false);
    if (!await _confirm(
      'Issue one-time token?',
      'Issue a temporary bearer credential for $userId with scopes '
          '${scopes.isEmpty ? '(none)' : scopes.join(' ')}. The raw value '
          'must be transferred through an approved secure channel.',
      confirmText: userId,
    )) {
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
      _tempToken = null;
    });
    try {
      final data = await widget.api.post(_tempTokenPath, {
        'user_id': userId,
        'scopes': scopes,
      });
      if (!mounted) return;
      final t =
          data['token']?.toString() ?? data['access_token']?.toString() ?? '';
      setState(() {
        if (t.isEmpty) {
          _error =
              'The token may have been issued, but Snaplink did not return '
              'its one-time value. Do not retry until you verify server state.';
          _tempToken = null;
        } else {
          _tempToken = t;
        }
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _revokeToken() async {
    final value = _revokeTokenCtrl.text.trim();
    if (value.isEmpty) {
      setState(
        () => _error = _revokeKind == 'token'
            ? 'Enter the raw token value.'
            : 'Enter a session ID.',
      );
      return;
    }
    final confirmed = await _confirm(
      _revokeKind == 'token' ? 'Revoke token?' : 'Revoke session?',
      'This revocation is immediate and cannot be undone.',
      confirmText: _revokeKind == 'session_id' ? value : null,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.post(_singleRevokePath, {_revokeKind: value});
      if (!mounted) return;
      _revokeTokenCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            _revokeKind == 'token' ? 'Token revoked.' : 'Session revoked.',
          ),
        ),
      );
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (_revokeKind == 'token') _revokeTokenCtrl.clear();
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'token-security') return;
    final section = route.subresource.isNotEmpty ? route.subresource : 'all';
    if (_sectionDefs.any((s) => s.id == section)) {
      setState(() {
        _currentSection = section;
        if (section != 'all' && section != 'temp') _tempToken = null;
      });
    }
  }

  void _selectSection(String section) {
    setState(() {
      _currentSection = section;
      if (section != 'all' && section != 'temp') _tempToken = null;
    });
    if (section == 'all') {
      AdminRoute.go('token-security');
    } else {
      AdminRoute.go('token-security', subresource: section);
    }
  }

  /// 安全摘要（异常优先）：可疑/临期计数大数字，第一时间看到风险量级。
  Widget _securitySummary(BuildContext context) {
    final suspicious = _list('suspicious', 'findings').length;
    final expiring = _list('expiring', 'tokens').length;
    final sessions = _data['sessions']?['total'] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        children: [
          _summaryStat(context, 'Anomalies', suspicious,
              suspicious > 0 ? AppColors.danger : AppColors.muted,
              Icons.warning_amber_outlined),
          const SizedBox(width: 24),
          _summaryStat(context, 'Expiring', expiring,
              expiring > 0 ? AppColors.warning : AppColors.muted,
              Icons.timer_outlined),
          const SizedBox(width: 24),
          _summaryStat(context, 'Sessions', sessions,
              AppColors.muted, Icons.devices_outlined),
        ],
      ),
    );
  }

  Widget _summaryStat(BuildContext context, String label, int value,
      Color color, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        CountUp(
          value: value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        LocalizedText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _tempTokenCard(BuildContext context) =>
      _card(context, 'Create temporary token', [
        TextField(
          key: const Key('temp-token-user-id'),
          controller: _createUserCtrl,
          decoration: InputDecoration(labelText: 'User ID'.localized),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _createScopesCtrl,
          decoration: InputDecoration(
            labelText: 'Scopes (space-separated)'.localized,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('temp-token-submit'),
          onPressed: _mutating ? null : _createTempToken,
          child: const LocalizedText('Create temp token'),
        ),
        if (_tempToken != null) ...[
          const SizedBox(height: 8),
          const LocalizedText(
            'Save this token now. It will not be shown again.',
            style: TextStyle(color: AppColors.warning, fontSize: 12),
          ),
          SelectableText(
            _tempToken!,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => setState(() => _tempToken = null),
              child: const LocalizedText('I have saved it — clear token'),
            ),
          ),
        ],
      ]);
  Widget _revokeTokenCard(BuildContext context) =>
      _card(context, 'Revoke token or session', [
        DropdownButtonFormField<String>(
          initialValue: _revokeKind,
          decoration: InputDecoration(labelText: 'Credential type'.localized),
          items: const [
            DropdownMenuItem(
              value: 'session_id',
              child: LocalizedText('Session ID'),
            ),
            DropdownMenuItem(value: 'token', child: LocalizedText('Raw token')),
          ],
          onChanged: _mutating
              ? null
              : (value) => setState(() => _revokeKind = value!),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('single-revoke-value'),
          controller: _revokeTokenCtrl,
          obscureText: _revokeKind == 'token',
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText:
                (_revokeKind == 'token' ? 'Raw token' : 'Session ID').localized,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('single-revoke-submit'),
          onPressed: _mutating ? null : _revokeToken,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          child: const LocalizedText('Revoke token'),
        ),
      ]);
}
