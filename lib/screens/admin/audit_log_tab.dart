import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';

/// Audit log viewer tab.
/// Shows recent admin operations with search and filter.
/// URL: /admin/audit-log
class AuditLogTab extends StatefulWidget {
  const AuditLogTab({super.key});
  @override
  State<AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<AuditLogTab> {
  final _logService = AuditLogService();
  final _searchCtrl = TextEditingController();
  String _methodFilter = 'ALL';
  List<AuditEntry> _entries = [];
  String _sortColumn = 'time';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      var filtered = _logService.entries;
      if (_methodFilter != 'ALL') {
        filtered = filtered.where((e) => e.method == _methodFilter).toList();
      }
      final query = _searchCtrl.text.trim();
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        filtered = filtered
            .where(
              (e) =>
                  e.path.toLowerCase().contains(q) ||
                  e.label.toLowerCase().contains(q),
            )
            .toList();
      }
      _entries = filtered;
      _sortEntries();
    });
  }

  void _sortEntries() {
    final column = _sortColumn;
    final sorted = [..._entries];
    sorted.sort((a, b) {
      int cmp;
      switch (column) {
        case 'method':
          cmp = a.method.compareTo(b.method);
        case 'status':
          cmp = a.statusCode.compareTo(b.statusCode);
        case 'label':
          cmp = a.label.toLowerCase().compareTo(b.label.toLowerCase());
        default:
          cmp = a.timestamp.compareTo(b.timestamp);
      }
      return _sortAscending ? cmp : -cmp;
    });
    _entries = sorted;
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _sortEntries();
    });
  }

  /// 导出当前过滤结果为 CSV（剪贴板，跨平台通用）。
  /// 单元格以 = + - @ 开头时加前缀防 CSV 公式注入（security spec）。
  Future<void> _exportCsv() async {
    final sb = StringBuffer('timestamp,method,path,status,label\n');
    for (final e in _entries) {
      final cells = [
        e.timestamp.toUtc().toIso8601String(),
        e.method,
        e.path,
        '${e.statusCode}',
        e.label,
      ].map(_csvCell).join(',');
      sb.writeln(cells);
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
              'Exported ${_entries.length} entries as CSV to clipboard'),
        ),
      );
    }
  }

  /// CSV 单元格转义：引号翻倍；公式注入前缀字符转义。
  String _csvCell(String value) {
    var cell = value.replaceAll('"', '""');
    if (cell.startsWith(RegExp(r'[=+\-@]'))) {
      cell = "'$cell";
    }
    return '"$cell"';
  }

  double _errorRate(BuildContext context) {
    final total = _logService.count;
    if (total == 0) return 0;
    final errors = _logService.entries
        .where((e) => e.statusCode >= 400)
        .length;
    return errors * 100.0 / total;
  }

  Widget _errorRateBadge(BuildContext context) {
    final rate = _errorRate(context);
    return StatusChip(
      label: '${rate.round()}% errors',
      color: rate >= 20
          ? AppColors.danger
          : rate >= 5
          ? AppColors.warning
          : AppColors.success,
      icon: rate >= 20 ? Icons.error_outline : Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      AdminListHeader(
        title: 'Audit Log',
        subtitle: 'All authentication and administrative events recorded on this device.',
        onRefresh: _refresh,
        actions: [
          LocalizedText('{count} entries', args: {'count': _logService.count}),
          if (_errorRate(context) > 0) ...[
            const SizedBox(width: 8),
            _errorRateBadge(context),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh'.localized,
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV'.localized,
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear log'.localized,
            onPressed: _logService.count == 0
                ? null
                : () async {
                    final confirmed = await ConfirmDialog.show(
                      context,
                      title: 'Clear audit log?',
                      message: 'This will permanently delete all '
                          '${_logService.count} local audit entries.',
                      confirmLabel: 'Clear log',
                      destructive: true,
                    );
                    if (!confirmed) return;
                    _logService.clear();
                    _refresh();
                  },
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by path, label...'.localized,
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
            value: _methodFilter,
            items: const [
              DropdownMenuItem(
                value: 'ALL',
                child: LocalizedText('All methods'),
              ),
              DropdownMenuItem(value: 'POST', child: LocalizedText('Create')),
              DropdownMenuItem(value: 'PUT', child: LocalizedText('Update')),
              DropdownMenuItem(value: 'DELETE', child: LocalizedText('Delete')),
              DropdownMenuItem(value: 'PATCH', child: LocalizedText('Modify')),
            ],
            onChanged: (v) {
              setState(() => _methodFilter = v ?? 'ALL');
              _refresh();
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (_entries.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 40),
            child: LocalizedText(
              'No audit entries yet. Operations will appear here.',
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
                _formatTime(_entries[i].timestamp),
                muted: true,
              ),
            ),
            AdminDataColumn(
              id: 'method',
              label: 'METHOD',
              width: 130,
              sortable: true,
              builder: (context, i) {
                final entry = _entries[i];
                final color = switch (entry.method) {
                  'POST' => AppColors.success,
                  'DELETE' => AppColors.danger,
                  _ => AppColors.muted,
                };
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.method == 'POST'
                          ? Icons.add_circle_outline
                          : entry.method == 'DELETE'
                          ? Icons.remove_circle_outline
                          : Icons.change_circle_outlined,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    TableCellText(entry.method, bold: true),
                  ],
                );
              },
            ),
            AdminDataColumn(
              id: 'status',
              label: 'STATUS',
              width: 100,
              sortable: true,
              builder: (context, i) {
                final code = _entries[i].statusCode;
                return TableCellText(
                  '$code',
                  color: code >= 400
                      ? AppColors.danger
                      : code >= 300
                      ? AppColors.warning
                      : AppColors.success,
                  bold: true,
                );
              },
            ),
            AdminDataColumn(
              id: 'label',
              label: 'EVENT',
              width: 220,
              sortable: true,
              builder: (context, i) =>
                  TableCellText(_entries[i].label, bold: true),
            ),
            AdminDataColumn(
              id: 'path',
              label: 'PATH',
              builder: (context, i) => TableCellText(
                _entries[i].path,
                muted: true,
                maxLines: 2,
              ),
            ),
          ],
          itemCount: _entries.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
    ],
  );

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
