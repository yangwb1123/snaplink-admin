import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:sso_admin/api/audit_event_row.dart';
import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/status_chip.dart';

/// Audit log viewer tab — server read.
///
/// Renders the sink's audit events through [AuditReadClient] (the sole
/// owner of the trio path literals); the localStorage ring is demoted to
/// a debug-only recording surface (B6-1b) and is never a data source.
/// URL: /admin/audit-log
class AuditLogTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  /// Optional tenant/trace context, forwarded verbatim into
  /// [AuditReadClient]. Never derived, never hardcoded, never defaulted —
  /// B4-1 claim parsing / proxy-side trace_id injection are [PROPOSED] and
  /// out of scope; when absent the wire stays exactly `{'limit':'100'}`
  /// (AC-1).
  final String? tenantId;
  final String? traceId;

  const AuditLogTab({
    super.key,
    required this.api,
    required this.capabilities,
    this.tenantId,
    this.traceId,
  });

  @override
  State<AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<AuditLogTab> {
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
    _client = AuditReadClient(
      widget.api,
      tenantId: widget.tenantId,
      traceId: widget.traceId,
    );
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Read flow: capability gate first (zero requests when the trio is not
  /// served), then a fresh page from the client. Errors render via
  /// `toString()` only — never `error.data` (FM-1).
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
    } on SnaplinkAdminApiError catch (error) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    } on TimeoutException catch (error) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = error.toString();
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
    final sorted = [...filtered]..sort(_compareRows);
    _displayed = sorted;
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
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _applyFilter();
    });
  }

  /// Export the filtered view as CSV (clipboard, cross-platform).
  /// Cells are always-quoted; CR/LF normalized first, quotes doubled, and
  /// OWASP formula-injection prefixes (= + - @ tab CR + unicode lookalikes)
  /// defused with a leading apostrophe (security spec).
  Future<void> _exportCsv() async {
    final sb = StringBuffer(
      'timestamp,type,outcome,id,actor_id,client_id,tenant_id\n',
    );
    for (final row in _displayed) {
      final cells = [
        row.timestamp?.toUtc().toIso8601String() ?? '--',
        row.type,
        row.outcome,
        row.id,
        row.actorId,
        row.clientId,
        row.tenantId,
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
    var cell = value
        .replaceAll('\r\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');
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

  Widget _errorRateBadge(BuildContext context) {
    final rate = _errorRate();
    return StatusChip(
      label: context.tr('{n}% errors', {'n': rate.round()}),
      color: rate >= 20
          ? AppColors.danger
          : rate >= 5
          ? AppColors.warning
          : AppColors.success,
      icon: rate >= 20 ? Icons.error_outline : Icons.check_circle_outline,
    );
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

  @override
  Widget build(BuildContext context) {
    final ringCount = _logService.count;
    final showEmpty =
        _rows.isEmpty && !_loading && _error == null && !_notEnabled;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: 'Audit Log',
          subtitle:
              'All authentication and administrative events recorded by the server.',
          onRefresh: _refresh,
          actions: [
            LocalizedText('{count} entries', args: {'count': _rows.length}),
            if (_errorRate() > 0) ...[
              const SizedBox(width: 8),
              _errorRateBadge(context),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'.localized,
              onPressed: _loading ? null : _refresh,
            ),
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export CSV'.localized,
              onPressed: _exportCsv,
            ),
            // Debug-only ring copy surface: const-folds out of release
            // builds; the flag keeps the landed B6-1b tests satisfiable.
            if (kDebugMode && AuditLogService.ringCopyEnabled) ...[
              const SizedBox(width: 4),
              StatusChip(
                label: context.tr('Debug records'),
                color: AppColors.warning,
                icon: Icons.bug_report_outlined,
              ),
              if (ringCount > 0) ...[
                const SizedBox(width: 4),
                LocalizedText(
                  'Debug records: {n} entries',
                  args: {'n': ringCount},
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear local debug records'.localized,
                onPressed: ringCount == 0 ? null : _clearRing,
              ),
            ],
          ],
        ),
        if (_notEnabled)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: LocalizedText(
                'This feature is not enabled on the connected replica.',
              ),
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: AppColors.danger, size: 32),
                  const SizedBox(height: 12),
                  Text(_error ?? '', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const LocalizedText('Retry'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search...'.localized,
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) => _refresh(),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _outcomeFilter,
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: LocalizedText('All'),
                  ),
                  DropdownMenuItem(
                    value: 'success',
                    child: LocalizedText('success'),
                  ),
                  DropdownMenuItem(
                    value: 'failure',
                    child: LocalizedText('failure'),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _outcomeFilter = v ?? 'ALL');
                  _refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (showEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: LocalizedText(
                  'No audit events returned by the server yet.',
                ),
              ),
            )
          else
            AdminDataTable(
              sortColumn: _sortColumn,
              sortAscending: _sortAscending,
              onSort: _onSort,
              minWidth: 900,
              columns: [
                AdminDataColumn(
                  id: 'time',
                  label: 'TIME',
                  width: 180,
                  sortable: true,
                  builder: (context, i) => TableCellText(
                    _formatTime(_displayed[i].timestamp),
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'type',
                  label: 'EVENT',
                  width: 220,
                  sortable: true,
                  builder: (context, i) =>
                      TableCellText(_displayed[i].type, bold: true),
                ),
                AdminDataColumn(
                  id: 'outcome',
                  label: 'OUTCOME',
                  // Wide enough for the chip under the monospace test
                  // font (7-char labels render ~116px).
                  width: 160,
                  sortable: true,
                  builder: (context, i) {
                    final row = _displayed[i];
                    if (row.outcome.isEmpty) {
                      return const TableCellText('-', muted: true);
                    }
                    // Server vocabulary rendered verbatim (machine data,
                    // like EVENT) — the OUTCOME column never fabricates
                    // localized copy.
                    return StatusChip(
                      label: row.outcome,
                      color: row.outcome == 'success'
                          ? AppColors.success
                          : AppColors.danger,
                      icon: row.outcome == 'success'
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                    );
                  },
                ),
                AdminDataColumn(
                  id: 'actor',
                  label: 'ACTOR',
                  width: 140,
                  builder: (context, i) {
                    final actor = _displayed[i].actorId;
                    return TableCellText(actor.isEmpty ? '-' : actor);
                  },
                ),
                AdminDataColumn(
                  id: 'tenant',
                  label: 'TENANT',
                  width: 140,
                  builder: (context, i) {
                    final tenant = _displayed[i].tenantId;
                    return TableCellText(tenant.isEmpty ? '-' : tenant);
                  },
                ),
              ],
              itemCount: _displayed.length,
              rowBuilder: (context, i) => const SizedBox.shrink(),
            ),
        ],
      ],
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} '
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
