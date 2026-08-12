import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';
import 'snaplink_admin_api.dart';

/// Token security workbench: portfolio / anomalies / sessions / expiring
/// reads + bounded bulk revoke + one-time temp token + single revoke.
/// URLs: /admin/token-security[/:section]
class TokenSecurityTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const TokenSecurityTab({super.key, required this.api, required this.capabilities});
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
  bool _loading = true, _mutating = false;
  String? _tempToken;
  String _revokeKind = 'session_id', _currentSection = 'all';
  late final void Function() _cancelPopState;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.tokenSecurity);
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
  bool _supports(String method, String path) =>
      widget.capabilities.has(method, path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (e) => e.method == method && e.path == path.replaceAll('/:id', '/{id}'),
      );
  bool get _supportsBulkRevoke => _supports('POST', _bulkRevokePath);
  bool get _supportsTempToken => _supports('POST', _tempTokenPath);
  bool get _supportsSingleRevoke => _supports('POST', _singleRevokePath);
  bool get _supportsAdminTokenRevoke => _supports('DELETE', _adminTokenPath);
  SectionDef _def(String id, String label, IconData icon) =>
      SectionDef(id, label, icon, color: _accent);
  List<SectionDef> get _sections => [
    _def('all', 'All', Icons.dashboard),
    if (_supports('GET', _paths['portfolio']!)) _def('portfolio', 'Portfolio', Icons.account_balance_wallet),
    if (_supports('GET', _paths['suspicious']!)) _def('suspicious', 'Anomalies', Icons.warning),
    if (_supports('GET', _paths['sessions']!)) _def('sessions', 'Sessions', Icons.devices),
    if (_supports('GET', _paths['expiring']!)) _def('expiring', 'Expiring', Icons.timer),
    if (_supportsTempToken) _def('temp', 'Temp Token', Icons.key),
    if (_supportsSingleRevoke || _supportsBulkRevoke || _supportsAdminTokenRevoke)
      _def('revoke', 'Revoke', Icons.remove_circle),
  ];
  bool _shows(String section) => _currentSection == 'all' || _currentSection == section;
  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() { if (mounted) _handleRoute(); });
    _load();
  }
  @override
  void dispose() {
    _tempToken = null;
    _revokeTokenCtrl.clear();
    _cancelPopState();
    for (final c in [_subjectCtrl, _clientCtrl, _createUserCtrl, _createScopesCtrl, _revokeTokenCtrl]) { c.dispose(); }
    super.dispose();
  }
  Future<void> _load() async {
    widget.api.skipCache();
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait(
      _paths.entries.where((e) => _supports('GET', e.value)).map((e) async {
        try { return (key: e.key, data: await widget.api.get(e.value), error: null); }
        catch (error) { return (key: e.key, data: null, error: error); }
      }),
    );
    if (!mounted) return;
    final unavailable = results.where((r) => r.error != null).map((r) => r.key).join(', ');
    setState(() {
      _data..clear()..addEntries([for (final r in results) if (r.data != null) MapEntry(r.key, r.data!)]);
      _error = unavailable.isEmpty ? null : 'Some token data is unavailable: $unavailable.';
      _loading = false;
    });
  }
  List<Map<String, dynamic>> _list(String key, String valueKey) {
    final values = _data[key]?[valueKey];
    if (values is! List) return const [];
    return values.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList(growable: false);
  }
  Future<void> _write(Future<Map<String, dynamic>> Function() request, String message) async {
    setState(() => _mutating = true);
    try {
      await request();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: LocalizedText(message)));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
  Future<bool> _confirm(String title, String body, {String? confirmText}) =>
      ConfirmDialog.show(context, title: title, message: body, destructive: true, confirmText: confirmText);
  Future<void> _revokeAdminToken(String id) async {
    if (!await _confirm('Revoke administrator token?', 'The selected administrator session will immediately lose access.')) return;
    await _write(() => widget.api.delete('/api/v1/admin/tokens/${Uri.encodeComponent(id)}'), 'Administrator token revoked.');
  }
  Future<void> _bulkRevoke() async {
    final subject = _subjectCtrl.text.trim(), clientId = _clientCtrl.text.trim();
    if (subject.isEmpty && clientId.isEmpty) { setState(() => _error = 'Set a subject and/or client ID to bound the revocation.'); return; }
    if (!await _confirm('Bulk revoke refresh tokens?', 'Refresh tokens in the supplied scope will be invalidated. Existing stateless access tokens expire naturally.')) return;
    await _write(
      () => widget.api.post(_bulkRevokePath, {if (subject.isNotEmpty) 'subject': subject, if (clientId.isNotEmpty) 'client_id': clientId, 'confirm': true}),
      'Refresh-token revocation completed.',
    );
  }
  Future<void> _createTempToken() async {
    final userId = _createUserCtrl.text.trim();
    if (userId.isEmpty) { setState(() => _error = 'User ID is required.'); return; }
    final scopes = _createScopesCtrl.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList(growable: false);
    if (!await _confirm(
      'Issue one-time token?',
      'Issue a temporary bearer credential for $userId with scopes ${scopes.isEmpty ? '(none)' : scopes.join(' ')}. The raw value must be transferred through an approved secure channel.',
      confirmText: userId,
    )) {
      return;
    }
    setState(() { _mutating = true; _error = null; _tempToken = null; });
    try {
      final data = await widget.api.post(_tempTokenPath, {'user_id': userId, 'scopes': scopes});
      if (!mounted) return;
      final token = data['token']?.toString() ?? data['access_token']?.toString() ?? '';
      setState(() {
        if (token.isEmpty) {
          _error = 'The token may have been issued, but Snaplink did not return its one-time value. Do not retry until you verify server state.';
          _tempToken = null;
        } else { _tempToken = token; }
      });
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _mutating = false); }
  }
  Future<void> _revokeToken() async {
    final value = _revokeTokenCtrl.text.trim();
    if (value.isEmpty) { setState(() => _error = _revokeKind == 'token' ? 'Enter the raw token value.' : 'Enter a session ID.'); return; }
    if (!await _confirm(_revokeKind == 'token' ? 'Revoke token?' : 'Revoke session?', 'This revocation is immediate and cannot be undone.', confirmText: _revokeKind == 'session_id' ? value : null)) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.post(_singleRevokePath, {_revokeKind: value});
      if (!mounted) return;
      _revokeTokenCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: LocalizedText(_revokeKind == 'token' ? 'Token revoked.' : 'Session revoked.')));
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally {
      if (_revokeKind == 'token') _revokeTokenCtrl.clear();
      if (mounted) setState(() => _mutating = false);
    }
  }
  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'token-security') return;
    final section = route.subresource.isNotEmpty ? route.subresource : 'all';
    if (_sections.any((s) => s.id == section)) {
      setState(() { _currentSection = section; if (section != 'all' && section != 'temp') _tempToken = null; });
    }
  }
  void _selectSection(String section) {
    setState(() { _currentSection = section; if (section != 'all' && section != 'temp') _tempToken = null; });
    if (section == 'all') { AdminRoute.go('token-security'); } else { AdminRoute.go('token-security', subresource: section); }
  }
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminBreadcrumb(),
          Row(children: [
            Text(AppStrings.of(context).tokenSessionSecurity, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3)),
            const Spacer(),
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 4),
          const LocalizedText('Token issuance, lifetimes and rotation policies across clients.', style: TextStyle(fontSize: 12, color: AppColors.textSubtle)),
          const SizedBox(height: 8),
          SectionSelector(sections: _sections, current: _currentSection, onSelected: _selectSection),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) _ErrorBanner(error: _error!, onRetry: _load),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 16), child: SkeletonListTile(itemCount: 3))
            else if (_data.isEmpty) const EmptyState(compact: true, variant: EmptyStateVariant.empty, title: 'No token data available.')
            else ...[
              _securitySummary(context),
              if (_shows('portfolio') && _data.containsKey('portfolio')) _portfolioCard(),
              if (_shows('suspicious') && _data.containsKey('suspicious')) _listCard('suspicious'),
              if (_shows('sessions') && _data.containsKey('sessions')) _listCard('sessions'),
              if (_shows('revoke') && _data.containsKey('tokens')) _listCard('tokens'),
              if (_shows('expiring') && _data.containsKey('expiring')) _listCard('expiring'),
              if (_shows('revoke') && _supportsBulkRevoke) _bulkRevokeCard(),
              if (_shows('temp') && _supportsTempToken) _tempTokenCard(),
              if (_shows('revoke') && _supportsSingleRevoke) _revokeTokenCard(),
            ],
          ],
        ),
      ),
    ],
  );

  /// 统一卡片容器：组色图标 + SectionHeader 标题（SectionHeader 惯例）。
  Widget _card(String title, IconData icon, List<Widget> children) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(icon, size: 20, color: _accent), const SizedBox(width: 8), Expanded(child: SectionHeader(title))]),
        const SizedBox(height: 12),
        ...children,
      ]),
    ),
  );

  /// 列表卡：空态 EmptyState(compact)（X8），非空 AdminDataTable(compact)（X6）。
  Widget _tableCard({required String title, required IconData icon, required List<Map<String, dynamic>> rows, required String emptyText, required List<AdminDataColumn> columns, Widget? header}) =>
      _card(title, icon, [
        if (header != null) ...[header, const SizedBox(height: 12)],
        if (rows.isEmpty) EmptyState(compact: true, variant: EmptyStateVariant.empty, title: emptyText)
        else AdminDataTable(density: TableDensity.compact, columns: columns, itemCount: rows.length, rowBuilder: (_, _) => const SizedBox.shrink()),
      ]);

  /// 单行文本单元格（API 值走 TableCellText/Text，不参与 i18n 查表）。
  AdminDataColumn _cell(List<Map<String, dynamic>> rows, String id, String label, String Function(Map<String, dynamic>) value, {bool primary = false, bool muted = false}) => AdminDataColumn(
    id: id, label: label, cardPrimary: primary, cardDetail: !primary,
    builder: (_, i) => TableCellText(value(rows[i]), level: primary ? DataEmphasisLevel.primary : null, muted: muted),
  );
  Widget _listCard(String key) {
    final rows = switch (key) {
      'sessions' => _list('sessions', 'sessions').take(100).toList(growable: false),
      'suspicious' => _list('suspicious', 'findings'),
      'tokens' => _list('tokens', 'tokens'),
      _ => _list('expiring', 'tokens'),
    };
    final (title, icon, empty, header, columns) = switch (key) {
      'suspicious' => ('Detected token anomalies', Icons.warning_amber_outlined, 'No anomaly findings.', null, _anomalyColumns(rows)),
      'sessions' => ('Active sessions', Icons.devices_other_outlined, 'No sessions recorded.', LocalizedText('Total: {total}', args: {'total': _data['sessions']?['total'] ?? rows.length}), _sessionColumns(rows)),
      'tokens' => ('Administrator bearer tokens', Icons.admin_panel_settings_outlined, 'No administrator tokens found.', null, _adminTokenColumns(rows)),
      _ => ('Refresh tokens expiring soon', Icons.timer_outlined, 'No refresh-token expiry records.', null, _expiringColumns(rows)),
    };
    return _tableCard(title: title, icon: icon, rows: rows, emptyText: empty, header: header, columns: columns);
  }
  List<AdminDataColumn> _anomalyColumns(List<Map<String, dynamic>> rows) => [
    AdminDataColumn(id: 'finding', label: 'Finding', cardPrimary: true, builder: (_, i) {
      final f = rows[i], critical = f['severity'] == 'critical';
      return Row(children: [
        Icon(critical ? Icons.warning_amber : Icons.info_outline, size: 16, color: critical ? AppColors.danger : AppColors.warning),
        const SizedBox(width: 6),
        Expanded(child: Text('${f['type'] ?? ''} · ${f['subject_id'] ?? ''}', overflow: TextOverflow.ellipsis)),
      ]);
    }),
    _cell(rows, 'detail', 'Detail', (r) => r['detail']?.toString() ?? '', muted: true),
  ];
  List<AdminDataColumn> _sessionColumns(List<Map<String, dynamic>> rows) => [
    _cell(rows, 'session', 'Session ID', (r) => r['id']?.toString() ?? '', primary: true),
    _cell(rows, 'user', 'User · IP', (r) => '${r['user_id'] ?? r['userId'] ?? ''} · ${r['ip'] ?? ''}', muted: true),
  ];
  List<AdminDataColumn> _adminTokenColumns(List<Map<String, dynamic>> rows) => [
    AdminDataColumn(id: 'token', label: 'Token', cardPrimary: true, builder: (_, i) {
      final t = rows[i];
      return Row(children: [
        Expanded(child: TableCellText(t['label']?.toString() ?? t['id']?.toString() ?? '', level: DataEmphasisLevel.primary)),
        if (_supportsAdminTokenRevoke) TextButton(
          onPressed: _mutating ? null : () => _revokeAdminToken(t['id']?.toString() ?? ''),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const LocalizedText('Revoke'),
        ),
      ]);
    }),
    _cell(rows, 'meta', 'Admin · Scopes', (r) => '${r['admin_id'] ?? ''} · ${(r['scopes'] as List? ?? const []).join(' ')}', muted: true),
  ];
  List<AdminDataColumn> _expiringColumns(List<Map<String, dynamic>> rows) => [
    _cell(rows, 'subject', 'Subject', (r) => r['subject']?.toString() ?? '', primary: true),
    _cell(rows, 'meta', 'Client · Expires', (r) => '${r['client_id'] ?? ''} · ${r['expires_at'] ?? ''}', muted: true),
  ];
  Widget _portfolioCard() {
    final portfolio = _data['portfolio']?['portfolio'] as Map? ?? const {};
    num metric(String k) => (portfolio[k] as num?) ?? 0;
    return _card('Token portfolio', Icons.account_balance_wallet_outlined, [
      MetricStrip(cards: [
        KeyMetricCard(label: 'Issued', value: metric('issued_total'), icon: Icons.token_outlined, color: _accent),
        KeyMetricCard(label: 'Introspections', value: metric('introspections'), icon: Icons.search_outlined, color: _accent),
        KeyMetricCard(label: 'Userinfo calls', value: metric('userinfo'), icon: Icons.person_outline, color: _accent),
      ]),
    ]);
  }
  Widget _bulkRevokeCard() => _card('Bounded refresh-token revocation', Icons.delete_sweep_outlined, [
    const LocalizedText('Supply at least one boundary. Snaplink rejects an unscoped revoke and may require confirmation for large batches.'),
    const SizedBox(height: 12),
    TextField(key: const Key('bulk-revoke-subject'), controller: _subjectCtrl, decoration: InputDecoration(labelText: 'Subject (optional)'.localized)),
    const SizedBox(height: 12),
    TextField(key: const Key('bulk-revoke-client'), controller: _clientCtrl, decoration: InputDecoration(labelText: 'Client ID (optional)'.localized)),
    const SizedBox(height: 12),
    OutlinedButton(key: const Key('bulk-revoke-submit'), onPressed: _mutating ? null : _bulkRevoke, style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)), child: const LocalizedText('Bulk revoke refresh tokens')),
  ]);
  Widget _tempTokenCard() => _card('Create temporary token', Icons.key_outlined, [
    TextField(key: const Key('temp-token-user-id'), controller: _createUserCtrl, decoration: InputDecoration(labelText: 'User ID'.localized)),
    const SizedBox(height: 12),
    TextField(controller: _createScopesCtrl, decoration: InputDecoration(labelText: 'Scopes (space-separated)'.localized)),
    const SizedBox(height: 12),
    FilledButton(key: const Key('temp-token-submit'), onPressed: _mutating ? null : _createTempToken, child: const LocalizedText('Create temp token')),
    if (_tempToken != null) ...[
      const SizedBox(height: 8),
      const LocalizedText('Save this token now. It will not be shown again.', style: TextStyle(color: AppColors.warning, fontSize: 12)),
      SelectableText(_tempToken!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: () => setState(() => _tempToken = null), child: const LocalizedText('I have saved it — clear token'))),
    ],
  ]);
  Widget _revokeTokenCard() => _card('Revoke token or session', Icons.remove_circle_outline, [
    DropdownButtonFormField<String>(initialValue: _revokeKind, decoration: InputDecoration(labelText: 'Credential type'.localized), items: const [
      DropdownMenuItem(value: 'session_id', child: LocalizedText('Session ID')),
      DropdownMenuItem(value: 'token', child: LocalizedText('Raw token')),
    ], onChanged: _mutating ? null : (v) => setState(() => _revokeKind = v!)),
    const SizedBox(height: 12),
    TextField(key: const Key('single-revoke-value'), controller: _revokeTokenCtrl, obscureText: _revokeKind == 'token', enableSuggestions: false, autocorrect: false, decoration: InputDecoration(labelText: (_revokeKind == 'token' ? 'Raw token' : 'Session ID').localized)),
    const SizedBox(height: 12),
    OutlinedButton(key: const Key('single-revoke-submit'), onPressed: _mutating ? null : _revokeToken, style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)), child: const LocalizedText('Revoke token')),
  ]);

  /// 安全摘要（异常优先）：可疑/临期计数大数字，第一时间看到风险量级。
  Widget _securitySummary(BuildContext context) {
    final suspicious = _list('suspicious', 'findings').length;
    final expiring = _list('expiring', 'tokens').length;
    final sessions = (_data['sessions']?['total'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: MetricStrip(cards: [
        KeyMetricCard(label: 'Anomalies', value: suspicious, icon: Icons.warning_amber_outlined, color: suspicious > 0 ? AppColors.danger : AppColors.muted),
        KeyMetricCard(label: 'Expiring', value: expiring, icon: Icons.timer_outlined, color: expiring > 0 ? AppColors.warning : AppColors.muted),
        KeyMetricCard(label: 'Sessions', value: sessions, icon: Icons.devices_outlined, color: AppColors.muted),
      ]),
    );
  }
}

/// 错误横幅（X4 模式）：图标 + 消息（API 值走 Text）+ Retry。
class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 12), child: Icon(Icons.error_outline, size: 18, color: AppColors.danger)),
        const SizedBox(width: 8),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error, style: const TextStyle(color: AppColors.danger)))),
        TextButton(onPressed: onRetry, child: const LocalizedText('Retry')),
      ]),
    ),
  );
}