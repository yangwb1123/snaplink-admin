import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:sso_admin/api/audit_event_row.dart';
import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'list_metrics.dart';

/// Audit log viewer tab — server read.
///
/// Renders the sink's audit events through [AuditReadClient] (sole owner of
/// the trio path literals); the localStorage ring is a debug-only recording
/// surface (B6-1b), never a data source. URL: /admin/audit-log
class AuditLogTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  /// Optional tenant/trace context forwarded verbatim into [AuditReadClient]
  /// (B4-1 [PROPOSED]); when absent the wire stays exactly `{'limit':'100'}`
  /// (AC-1).
  final String? tenantId;
  final String? traceId;

  /// Persona emphasis (derived by the dashboard; default = no emphasis).
  final OperatorPersona persona;

  const AuditLogTab({
    super.key,
    required this.api,
    required this.capabilities,
    this.tenantId,
    this.traceId,
    this.persona = OperatorPersona.general,
  });

  @override
  State<AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<AuditLogTab> {
  /// 模块组色（system → indigo）：页头图标按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.auditLog);

  late final AuditReadClient _client;
  final _logService = AuditLogService();
  final _searchCtrl = TextEditingController();

  List<AuditEventRow> _rows = const []; // server truth
  List<AuditEventRow> _displayed = const []; // filtered/sorted view
  bool _loading = false;
  String? _error;
  bool _notEnabled = false;
  int _generation = 0; // stale-response guard (FM-4)
  String _outcomeFilter = 'ALL'; // 'ALL' | 'success' | 'failure'
  String _sortColumn = 'time';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _client = AuditReadClient(widget.api, tenantId: widget.tenantId, traceId: widget.traceId);
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Read flow: capability gate first (zero requests when gated), then a
  /// fresh page. Errors render via `toString()` only — never `error.data`
  /// (FM-1); timeouts land in the same single state (FM-2).
  Future<void> _refresh() async {
    if (!widget.capabilities.has('GET', AuditReadClient.eventsPath)) {
      setState(() {
        _notEnabled = true;
        _loading = false;
        _error = null;
        _rows = const [];
        _displayed = const [];
      });
      return;
    }
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _notEnabled = false;
    });
    try {
      final rows = await _client.list(limit: 100);
      if (!mounted || gen != _generation) return;
      setState(() {
        _rows = rows;
        _applyFilter();
        _loading = false;
      });
    } catch (error) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    Iterable<AuditEventRow> filtered = _rows;
    if (_outcomeFilter != 'ALL') {
      filtered = filtered.where((row) => row.outcome == _outcomeFilter);
    }
    if (query.isNotEmpty) {
      filtered = filtered.where(
        (row) =>
            row.type.toLowerCase().contains(query) ||
            row.outcome.toLowerCase().contains(query) ||
            row.actorId.toLowerCase().contains(query) ||
            row.clientId.toLowerCase().contains(query) ||
            row.tenantId.toLowerCase().contains(query) ||
            row.id.toLowerCase().contains(query),
      );
    }
    _displayed = [...filtered]..sort(_compareRows);
  }

  int _compareRows(AuditEventRow a, AuditEventRow b) {
    switch (_sortColumn) {
      case 'type':
        return a.type.toLowerCase().compareTo(b.type.toLowerCase());
      case 'outcome':
        return a.outcome.compareTo(b.outcome);
      default: // time — null timestamps sort last
        final at = a.timestamp;
        final bt = b.timestamp;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
    }
  }

  void _onSort(String column) {
    setState(() {
      final same = _sortColumn == column;
      _sortColumn = column;
      _sortAscending = same ? !_sortAscending : true;
      _applyFilter();
    });
  }

  /// Export the filtered view as CSV (clipboard, cross-platform). Cells are
  /// always-quoted; CR/LF normalized, quotes doubled, and OWASP formula-
  /// injection prefixes (= + - @ tab CR + unicode lookalikes) defused (sec).
  Future<void> _exportCsv() async {
    final sb = StringBuffer(
      'timestamp,type,outcome,id,actor_id,client_id,tenant_id\n',
    );
    for (final row in _displayed) {
      final cells = [
        row.timestamp?.toUtc().toIso8601String() ?? '--',
        row.type, row.outcome, row.id, row.actorId, row.clientId, row.tenantId,
      ].map(_csvCell).join(',');
      sb.writeln(cells);
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            'Exported {n} entries as CSV to clipboard',
            args: {'n': _displayed.length},
          ),
        ),
      );
    }
  }

  String _csvCell(String value) {
    var cell = value.replaceAll('\r\n', ' ').replaceAll('\r', ' ').replaceAll('\n', ' ');
    cell = cell.replaceAll('"', '""');
    final trimmed = cell.trimLeft();
    if (trimmed.isNotEmpty &&
        (const ['=', '+', '-', '@', '\t', '\r'].contains(trimmed[0]) ||
            _csvLookalikePrefix.contains(trimmed[0]))) {
      cell = "'$cell";
    }
    return '"$cell"';
  }

  /// Fullwidth lookalikes of the OWASP formula-injection prefixes.
  static const _csvLookalikePrefix = {'＝', '＋', '－', '＠'};

  double _errorRate() {
    if (_rows.isEmpty) return 0;
    final errors = _rows.where((row) => row.outcome == 'failure').length;
    return errors * 100.0 / _rows.length;
  }

  /// Debug-only ring clear (B6-1b): ring-scoped copy, ring-only effect.
  Future<void> _clearRing() async {
    final ringCount = _logService.count;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Clear local debug records?',
      message:
          'This will permanently delete all $ringCount local debug records.',
      confirmLabel: 'Clear local debug records',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _logService.clear();
    _refresh();
  }

  Widget _outcomeCell(AuditEventRow row) {
    if (row.outcome.isEmpty) return const TableCellText('-', muted: true);
    // Server vocabulary rendered verbatim (machine data, like EVENT).
    return StatusChip(
      label: row.outcome,
      color: row.outcome == 'success' ? AppColors.success : AppColors.danger,
      icon: row.outcome == 'success' ? Icons.check_circle_outline : Icons.error_outline,
    );
  }

  /// Header actions: server-truth count, error-rate badge, refresh/export,
  /// and the debug-only ring copy surface (const-folds out of release).
  List<Widget> _actions(BuildContext context) {
    final ringCount = _logService.count;
    return [
      LocalizedText('{count} entries', args: {'count': _rows.length}),
      if (_errorRate() > 0)
        StatusChip(
          label: context.tr('{n}% errors', {'n': _errorRate().round()}),
          color: _errorRate() >= 20
              ? AppColors.danger
              : _errorRate() >= 5
              ? AppColors.warning
              : AppColors.success,
          icon: _errorRate() >= 20
              ? Icons.error_outline
              : Icons.check_circle_outline,
        ),
      IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh'.localized, onPressed: _loading ? null : _refresh),
      IconButton(icon: const Icon(Icons.file_download_outlined), tooltip: 'Export CSV'.localized, onPressed: _exportCsv),
      if (kDebugMode && AuditLogService.ringCopyEnabled) ...[
        StatusChip(label: context.tr('Debug records'), color: AppColors.warning, icon: Icons.bug_report_outlined),
        if (ringCount > 0)
          LocalizedText('Debug records: {n} entries', args: {'n': ringCount}),
        IconButton(icon: const Icon(Icons.delete_sweep), tooltip: 'Clear local debug records'.localized, onPressed: ringCount == 0 ? null : _clearRing),
      ],
    ];
  }

  /// 页头：图标按模块组色上色（X7），标题/副标题走 i18n 字面量。
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.receipt_long_outlined, color: _accent, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Audit Log'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text(context.tr('All authentication and administrative events recorded by the server.'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _actions(context),
          ),
        ),
      ]),
    );
  }

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）；错误文本动态 Text（FM-1）。
  Widget _errorCard(BuildContext context) =>
      ErrorStateCard(message: _error ?? '', onRetry: _refresh);

  @override
  Widget build(BuildContext context) {
    final showEmpty = _rows.isEmpty && !_loading && _error == null && !_notEnabled;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        _header(context),
        if (_notEnabled)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(variant: EmptyStateVariant.notEnabled),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _errorCard(context),
          )
        else ...[
          AuditMetrics(rows: _rows, persona: widget.persona),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 300,
              // 必须同步刷新（AC-1.6/F5）：无 debounce。
              child: SearchFilterBar(debounce: false, hintText: 'Search...'.localized, controller: _searchCtrl, onSearchChanged: (_) => _refresh()),
            ),
            const SizedBox(width: 12),
            StatusFilterDropdown(
              value: _outcomeFilter,
              options: const {'ALL': 'All', 'success': 'success', 'failure': 'failure'},
              onChanged: (v) {
                setState(() => _outcomeFilter = v);
                _refresh();
              },
            ),
          ]),
          const SizedBox(height: 16),
          SectionHeader('Recent events', count: _rows.length),
          const SizedBox(height: 8),
          if (_loading)
            const SkeletonListTile(itemCount: 4)
          else if (showEmpty)
            const EmptyState(variant: EmptyStateVariant.empty, title: 'No audit events returned by the server yet.')
          else
            AdminDataTable(
              density: TableDensity.compact,
              sortColumn: _sortColumn,
              sortAscending: _sortAscending,
              onSort: _onSort,
              minWidth: 900,
              columns: [
                AdminDataColumn(id: 'time', label: 'TIME', width: 180, sortable: true, builder: (c, i) => TableCellText(_formatTime(_displayed[i].timestamp), muted: true)),
                AdminDataColumn(id: 'type', label: 'EVENT', width: 220, sortable: true, builder: (c, i) => TableCellText(_displayed[i].type, bold: true)),
                AdminDataColumn(id: 'outcome', label: 'OUTCOME', width: 160, sortable: true, builder: (c, i) => _outcomeCell(_displayed[i])),
                AdminDataColumn(id: 'actor', label: 'ACTOR', width: 140, builder: (c, i) => TableCellText(_displayed[i].actorId.isEmpty ? '-' : _displayed[i].actorId)),
                AdminDataColumn(id: 'tenant', label: 'TENANT', width: 140, builder: (c, i) => TableCellText(_displayed[i].tenantId.isEmpty ? '-' : _displayed[i].tenantId)),
              ],
              itemCount: _displayed.length,
              rowBuilder: (context, i) => const SizedBox.shrink(),
            ),
        ],
      ],
    );
  }

  // Relative labels only — date fallback and '--' stay verbatim.
  String _formatTime(DateTime? dt) {
    if (dt == null) return '--';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return context.tr('just now');
    if (diff.inMinutes < 60) return context.tr('{count}m ago', {'count': diff.inMinutes});
    if (diff.inHours < 24) return context.tr('{count}h ago', {'count': diff.inHours});
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
