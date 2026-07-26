import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'admin_route.dart';

/// Domain ownership management tab with URL routing.
/// URLs: /admin/domains, /admin/domains/new
class DomainsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const DomainsTab({super.key, required this.api, required this.capabilities});
  @override
  State<DomainsTab> createState() => _DomainsTabState();
}

class _DomainsTabState extends State<DomainsTab> {
  static const _path = '/api/v1/admin/domains';
  final _hostCtrl = TextEditingController();
  List<Map<String, dynamic>> _domains = const [];
  String? _error; bool _loading = false; bool _mutating = false;
  bool _showForm = false;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_path);
  @override void dispose() { _hostCtrl.dispose(); super.dispose(); }

  @override
  void initState() {
    super.initState();
    _load();
    _handleRoute();
    void popListener() { if (mounted) _handleRoute(); }
    web.window.addEventListener('popstate', popListener.toJS);
  }

  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    setState(() => _showForm = route.isNew);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.get(_path);
      final items = data['domains'] as List? ?? [];
      if (!mounted) return;
      setState(() { _domains = items.map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    } catch (_) { if (mounted) setState(() { _error = 'Could not load domains.'; _loading = false; }); }
  }

  Future<void> _create() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) { setState(() => _error = 'Enter a hostname.'); return; }
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.post(_path, {'hostname': host});
      if (!mounted) return; _hostCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Domain added.')));
      if (mounted) AdminRoute.go('domains');
      await _load();
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _mutating = false); }
  }

  Future<void> _delete(String hostname) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Delete domain?', message: 'Delete $hostname?', confirmLabel: 'Delete', destructive: true);
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.delete('$_path/${Uri.encodeComponent(hostname)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Domain deleted.')));
      await _load();
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _mutating = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const Center(child: Text('Domain management is not enabled.'));
    return ListView(padding: const EdgeInsets.all(16), children: [
      AdminBreadcrumb(),
      Text('Domains', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4), const Text('Manage email domains for home-realm discovery.'),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      if (_showForm) _buildForm(context),
      const SizedBox(height: 16),
      if (_domains.isNotEmpty) ...[
        Row(children: [Text('Registered domains', style: Theme.of(context).textTheme.titleMedium), const Spacer(), IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
        const SizedBox(height: 8),
      ],
      if (_loading) const SkeletonListTile(itemCount: 3),
      if (!_loading && _domains.isEmpty && !_showForm) const Padding(padding: EdgeInsets.only(top: 12), child: Text('No domains registered.')),
      if (!_loading) for (final d in _domains) Card(margin: const EdgeInsets.only(top: 8), child: ListTile(
        leading: Icon(Icons.language, color: Colors.blue),
        title: Text(d['hostname']?.toString() ?? ''),
        subtitle: Text('verified: ${d['verified'] == true ? 'yes' : 'no'} · ${d['id'] ?? ''}'),
        trailing: TextButton(onPressed: _mutating ? null : () => _delete(d['hostname']?.toString() ?? ''), style: TextButton.styleFrom(foregroundColor: Colors.redAccent), child: const Text('Delete')),
      )),
      if (!_showForm)
        Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(
          onPressed: () => AdminRoute.go('domains', action: 'new'),
          icon: const Icon(Icons.add), label: const Text('Add domain'),
        )),
    ]);
  }

  Widget _buildForm(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Add domain', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      TextField(controller: _hostCtrl, decoration: const InputDecoration(labelText: 'Hostname', hintText: 'example.com')),
      const SizedBox(height: 10),
      OverflowBar(children: [
        OutlinedButton(onPressed: () => AdminRoute.go('domains'), child: const Text('Cancel')),
        const SizedBox(width: 8),
        FilledButton(onPressed: _mutating ? null : _create, child: const Text('Add domain')),
      ]),
    ])),
  );
}
