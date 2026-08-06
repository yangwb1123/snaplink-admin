import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
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
          LocalizedText('${_logService.count} entries'),
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
        ...List.generate(_entries.length, (i) {
          final entry = _entries[i];
          final icon = switch (entry.method) {
            'POST' => Icons.add_circle_outline,
            'PUT' => Icons.edit_outlined,
            'DELETE' => Icons.remove_circle_outline,
            _ => Icons.change_circle_outlined,
          };
          final color = switch (entry.method) {
            'POST' => AppColors.success,
            'DELETE' => AppColors.danger,
            _ => AppColors.muted,
          };
          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              leading: Icon(icon, color: color, size: 20),
              title: LocalizedText(
                entry.label,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: LocalizedText(
                '${entry.path} · ${_formatTime(entry.timestamp)} · ${entry.method} ${entry.statusCode}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        }),
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
