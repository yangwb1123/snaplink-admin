import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'admin_route.dart';

/// Threat detection policy management tab.
/// URLs: /admin/threat-policies, /admin/threat-policies/new, /admin/threat-policies/{id}/edit
class ThreatPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const ThreatPoliciesTab({super.key, required this.api, required this.capabilities});
  @override
  State<ThreatPoliciesTab> createState() => _ThreatPoliciesTabState();
}

class _ThreatPoliciesTabState extends State<ThreatPoliciesTab> {
  static const _path = '/api/v1/admin/threat-policies';
  List<Map<String, dynamic>> _policies = const [];
  String? _error; bool _loading = false; bool _mutating = false;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_path);
  @override void initState() { super.initState(); _load(); final p = () { if (mounted) _handleRoute(); }; web.window.addEventListener('popstate', p.toJS); }

  bool _editing = false;
  bool _creating = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  String? _editId;

  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    _creating = route.isNew;
    _editing = route.isEdit;
    _editId = route.resourceId;
    if (_creating) { _nameCtrl.clear(); _descCtrl.clear(); _rulesCtrl.clear(); }
    if (_editing && _editId != null) {
      final existing = _policies.where((p) => p['id']?.toString() == _editId).firstOrNull;
      if (existing != null) {
        _nameCtrl.text = existing['name']?.toString() ?? '';
        _descCtrl.text = existing['description']?.toString() ?? '';
        _rulesCtrl.text = existing['rules']?.toString() ?? existing['config']?.toString() ?? '';
      }
    }
    if (mounted) setState(() {});
  }

  @override void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); _rulesCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.get(_path);
      final items = data['policies'] as List? ?? [];
      if (!mounted) return;
      setState(() { _policies = items.map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; _handleRoute(); });
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
    catch (_) { if (mounted) setState(() { _error = 'Could not load threat policies.'; _loading = false; }); }
  }

  Future<void> _save() async {
    final body = {'name': _nameCtrl.text.trim(), 'description': _descCtrl.text.trim(), 'rules': _rulesCtrl.text.trim()};
    setState(() => _mutating = true);
    try {
      if (_editing && _editId != null) {
        await widget.api.put('$_path/${Uri.encodeComponent(_editId!)}', body);
      } else {
        await widget.api.post(_path, body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editing ? 'Policy updated.' : 'Policy created.')));
      if (mounted) AdminRoute.go('threat-policies');
      await _load();
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _mutating = false); }
  }

  Future<void> _delete(String id) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Delete policy?', message: 'Delete this threat policy?', confirmLabel: 'Delete', destructive: true);
    if (!confirmed) return;
    try {
      await widget.api.delete('$_path/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Policy deleted.')));
      await _load();
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const Center(child: Text('Threat policy management is not enabled.'));
    if (_creating || _editing) return _buildForm(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      AdminBreadcrumb(),
      Row(children: [
        Text('Threat Policies', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(),
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      if (_loading) const LinearProgressIndicator(),
      if (!_loading && _policies.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('No threat policies configured.')),
      if (!_loading) ...[
        Padding(padding: const EdgeInsets.only(bottom: 12), child: FilledButton.icon(
          onPressed: () => AdminRoute.go('threat-policies', action: 'new'),
          icon: const Icon(Icons.add), label: const Text('New policy'),
        )),
        for (final p in _policies) Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
          leading: Icon(Icons.shield, color: p['enabled'] == true ? Colors.green : Colors.grey),
          title: Text(p['name']?.toString() ?? ''),
          subtitle: Text('${p['description']?.toString() ?? ''}\n${p['id'] ?? ''}'),
          isThreeLine: true,
          onTap: () => AdminRoute.go('threat-policies', resourceId: p['id']?.toString() ?? '', action: 'edit'),
          trailing: TextButton(onPressed: () => _delete(p['id']?.toString() ?? ''), style: TextButton.styleFrom(foregroundColor: Colors.redAccent), child: const Text('Delete')),
        )),
      ],
    ]);
  }

  Widget _buildForm(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    AdminBreadcrumb(),
    Text(_editing ? 'Edit policy' : 'New policy', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 16),
    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
    const SizedBox(height: 12),
    TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
    const SizedBox(height: 12),
    TextField(controller: _rulesCtrl, decoration: const InputDecoration(labelText: 'Rules / Config'), maxLines: 4),
    const SizedBox(height: 16),
    OverflowBar(children: [
      OutlinedButton(onPressed: () => AdminRoute.go('threat-policies'), child: const Text('Cancel')),
      const SizedBox(width: 8),
      FilledButton(onPressed: _mutating ? null : _save, child: Text(_editing ? 'Update' : 'Create')),
    ]),
    if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
  ]);
}
