import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';

/// Token policy governance view tab.
class TokenPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const TokenPoliciesTab({super.key, required this.api, required this.capabilities});
  @override
  State<TokenPoliciesTab> createState() => _TokenPoliciesTabState();
}

class _TokenPoliciesTabState extends State<TokenPoliciesTab> {
  static const _path = '/api/v1/admin/token-policies';
  List<Map<String, dynamic>> _policies = const [];
  String? _error; bool _loading = false;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_path) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_path);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.get(_path);
      final items = data['policies'] as List? ?? data['token_policies'] as List? ?? [];
      if (!mounted) return;
      setState(() { _policies = items.map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    } catch (_) { if (mounted) setState(() { _error = 'Could not load token policies.'; _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const Center(child: Text('Token policy management is not enabled.'));
    return ListView(padding: const EdgeInsets.all(16), children: [
      AdminBreadcrumb(),
      Row(children: [
        Text('Token policies', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(), IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 4),
      const Text('Token issuance and validation policy configuration.'),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      if (_loading) const LinearProgressIndicator(),
      if (!_loading && _policies.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('No token policies configured.')),
      if (!_loading) for (final p in _policies) Card(margin: const EdgeInsets.only(top: 8), child: ListTile(
        leading: Icon(Icons.policy_outlined, color: Colors.indigo),
        title: Text(p['name']?.toString() ?? p['id']?.toString() ?? ''),
        subtitle: Text('${p['effect'] ?? p['action'] ?? 'allow'} · ${p['priority'] ?? ''}\n${p['description'] ?? ''}'),
        isThreeLine: true,
      )),
    ]);
  }
}
