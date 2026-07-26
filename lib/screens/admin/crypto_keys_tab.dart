import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'admin_route.dart';

/// Crypto keys inventory and rotation management tab.
/// URLs: /admin/crypto-keys, /admin/crypto-keys/rotate
class CryptoKeysTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const CryptoKeysTab({super.key, required this.api, required this.capabilities});
  @override
  State<CryptoKeysTab> createState() => _CryptoKeysTabState();
}

class _CryptoKeysTabState extends State<CryptoKeysTab> {
  static const _keysPath = '/api/v1/admin/crypto/keys';
  static const _rotatePath = '/api/v1/admin/keys/rotate';
  List<Map<String, dynamic>> _keys = const [];
  String? _error; bool _loading = false; bool _mutating = false;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_keysPath);
  bool get _canRotate => widget.capabilities.has('POST', _rotatePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_rotatePath);

  @override void initState() { super.initState(); if (_available) _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.get(_keysPath);
      final items = data['keys'] as List? ?? [];
      if (!mounted) return;
      setState(() { _keys = items.map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    } catch (_) { if (mounted) setState(() { _error = 'Could not load crypto keys.'; _loading = false; }); }
  }

  Future<void> _compromise(String id) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Mark key as compromised?', message: 'Key $id will be rotated out.', confirmLabel: 'Compromise', destructive: true);
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.post('$_keysPath/${Uri.encodeComponent(id)}/compromise');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Key marked as compromised.')));
      await _load();
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _mutating = false); }
  }

  Future<void> _rotate() async {
    final confirmed = await ConfirmDialog.show(context, title: 'Rotate keys?', message: 'Trigger coordinated key rotation across the cluster?', confirmLabel: 'Rotate', destructive: true);
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.post(_rotatePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Key rotation initiated.')));
      await _load();
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _mutating = false); }
  
  void handleRoute() {
    setState(() {});
  }
}

  @override
  Widget build(BuildContext context) {
    if (!_available) return const Center(child: Text('Crypto key management is not enabled on this replica.'));
    final route = AdminRoute.fromUri(Uri.base);
    final rotating = route.subresource == 'rotate';
    return ListView(padding: const EdgeInsets.all(16), children: [
      AdminBreadcrumb(),
      Row(children: [
        Text('Crypto keys', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(),
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      if (rotating) _buildRotateConfirm(context),
      if (_canRotate && !rotating)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: OutlinedButton.icon(
          onPressed: _mutating ? null : () => AdminRoute.go('crypto-keys', subresource: 'rotate'),
          icon: const Icon(Icons.refresh), label: const Text('Rotate keys'),
        )),
      if (_loading) const LinearProgressIndicator(),
      if (!_loading && _keys.isEmpty) const Text('No keys found.'),
      if (!_loading) for (final key in _keys) _keyCard(context, key),
    ]);
  }

  Widget _buildRotateConfirm(BuildContext context) => Card(
    color: Colors.orange.shade50,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      const Text('Rotate all crypto keys?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      const Text('This will generate new keys and mark existing ones as rotated. Services may experience a brief interruption.'),
      const SizedBox(height: 12),
      OverflowBar(children: [
        OutlinedButton(onPressed: () => AdminRoute.go('crypto-keys'), child: const Text('Cancel')),
        const SizedBox(width: 8),
        FilledButton(onPressed: _mutating ? null : _rotate, child: const Text('Confirm rotation')),
      ]),
    ])),
  );

  Widget _keyCard(BuildContext context, Map<String, dynamic> key) {
    final id = key['id']?.toString() ?? key['kid']?.toString() ?? '';
    final algorithm = key['algorithm']?.toString() ?? key['alg']?.toString() ?? '';
    final status = key['status']?.toString() ?? 'active';
    final createdAt = key['created_at']?.toString() ?? key['createdAt']?.toString() ?? '';
    final compromised = status == 'compromised';
    final expired = status == 'expired';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: Icon(
          compromised ? Icons.error : expired ? Icons.hourglass_empty : Icons.vpn_key,
          color: compromised ? Colors.red : expired ? Colors.orange : Colors.green,
        ),
        title: Text('$algorithm · $status'),
        subtitle: Text('$id\ncreated: $createdAt'),
        isThreeLine: true,
        trailing: compromised || expired ? null
            : TextButton(onPressed: _mutating ? null : () => _compromise(id),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Compromise')),
      ),
    );
  }
}
