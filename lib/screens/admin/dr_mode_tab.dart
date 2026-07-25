import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'dart:js_interop';
import 'admin_route.dart';
import 'package:web/web.dart' as web;

/// Disaster Recovery mode management tab.
/// URL: /admin/dr-mode
class DRModeTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const DRModeTab({super.key, required this.api, required this.capabilities});
  @override
  State<DRModeTab> createState() => _DRModeTabState();
}

class _DRModeTabState extends State<DRModeTab> {
  static const _path = '/api/v1/admin/dr-mode';
  Map<String, dynamic>? _status;
  String? _error; bool _loading = false; bool _mutating = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.get(_path);
      if (!mounted) return;
      setState(() { _status = data as Map<String, dynamic>?; _loading = false; });
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
    catch (_) { if (mounted) setState(() { _error = 'Could not load DR mode status.'; _loading = false; }); }
  }

  Future<void> _toggle() async {
    setState(() => _mutating = true);
    try {
      final current = _status?['mode']?.toString() ?? 'normal';
      final target = current == 'dr' ? 'normal' : 'dr';
      await widget.api.put(_path, {'mode': target});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switched to $target mode')));
      await _load();
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _mutating = false); }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    AdminBreadcrumb(),
    Text('Disaster Recovery', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 8),
    if (_loading) const LinearProgressIndicator(),
    if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
    if (_status != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Row(children: [
        Icon(Icons.sync_problem, size: 48, color: _status!['mode'] == 'dr' ? Colors.red : Colors.green),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Current mode: ${_status!['mode'] ?? 'normal'}', style: Theme.of(context).textTheme.titleMedium),
          Text('Replica: ${_status!['replica'] ?? _status!['role'] ?? 'primary'}'),
        ]),
      ]),
      if (_status!['mode'] == 'dr') ...[
        const Divider(),
        Text('⚠ Disaster Recovery mode is active. Some operations may be restricted.'),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _mutating ? null : _toggle,
        icon: Icon(_status!['mode'] == 'dr' ? Icons.check_circle : Icons.warning),
        label: Text(_status!['mode'] == 'dr' ? 'Switch to normal mode' : 'Enter DR mode'),
      ),
    ]))),
  ]);
}
