import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'admin_route.dart';

/// System health dashboard.
/// Shows connection status to the backend and basic server info.
class HealthTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  const HealthTab({super.key, required this.api});
  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> {
  Map<String, dynamic>? _health;
  Map<String, dynamic>? _storageHealth;
  Map<String, dynamic>? _federationHealth;
  String? _error;
  bool _loading = false;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _refresh();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.get('/health'),
        widget.api.get('/api/v1/admin/health/storage').catchError((_) => <String, dynamic>{}),
        widget.api.get('/api/v1/admin/health/federation').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _health = results[0] as Map<String, dynamic>?;
        _storageHealth = results[1] as Map<String, dynamic>?;
        _federationHealth = results[2] as Map<String, dynamic>?;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      Row(children: [
        Text('System Health', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(),
        IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      const SizedBox(height: 8),
      _serverCard(context),
      if (_storageHealth?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        _card(context, 'Storage Health', _storageHealth!, Icons.storage),
      ],
      if (_federationHealth?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        _card(context, 'Federation Health', _federationHealth!, Icons.lan),
      ],
      const SizedBox(height: 12),
      _debugCard(context),
    ],
  );

  Widget _serverCard(BuildContext context) {
    if (_loading && _health == null) {
      return const Card(child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ));
    }
    if (_error != null && _health == null) {
      return Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text('Cannot reach backend', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      ));
    }
    final h = _health ?? {};
    final status = h['status']?.toString() ?? 'unknown';
    final isOk = status == 'ok';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isOk ? Icons.check_circle : Icons.error, color: isOk ? Colors.green : Colors.redAccent, size: 32),
              const SizedBox(width: 12),
              Text('Backend Server', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Chip(label: Text(status.toUpperCase()),
                backgroundColor: isOk ? Colors.green.shade100 : Colors.red.shade100),
            ]),
            const Divider(),
            _row('Version', h['version']?.toString() ?? '—'),
            _row('Issuer', h['issuer']?.toString() ?? '—'),
            _row('Revision', (h['vcs_revision']?.toString() ?? '—').substring(0, 12)),
            _row('Build Time', h['vcs_time']?.toString() ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, Map<String, dynamic> data, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ]),
          const Divider(),
          if (data.isEmpty)
            const Text('No data available')
          else
            ...data.entries.map((e) => _row(e.key, e.value?.toString() ?? '—')),
        ],
      ),
    ),
  );

  Widget _debugCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline, size: 24),
          const SizedBox(width: 8),
          Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        ]),
        const Divider(),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(label: const Text('Audit Log'), onPressed: () => AdminRoute.go('audit-log')),
          ActionChip(label: const Text('Refresh Cache'), onPressed: () { widget.api.clearCache(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared'))); }),
          ActionChip(label: const Text('Test Connection'), onPressed: _refresh),
        ]),
      ]),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );
}
