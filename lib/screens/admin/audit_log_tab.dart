import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      Row(
        children: [
          Text('Audit Log', style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          Text('${_logService.count} entries'),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear log',
            onPressed: () {
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
              decoration: const InputDecoration(
                hintText: 'Search by path, label...',
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
              DropdownMenuItem(value: 'ALL', child: Text('All methods')),
              DropdownMenuItem(value: 'POST', child: Text('Create')),
              DropdownMenuItem(value: 'PUT', child: Text('Update')),
              DropdownMenuItem(value: 'DELETE', child: Text('Delete')),
              DropdownMenuItem(value: 'PATCH', child: Text('Modify')),
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
            child: Text('No audit entries yet. Operations will appear here.'),
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
            'POST' => Colors.green,
            'DELETE' => Colors.redAccent,
            _ => Colors.blueGrey,
          };
          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              leading: Icon(icon, color: color, size: 20),
              title: Text(entry.label, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
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
