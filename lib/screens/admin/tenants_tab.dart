import 'package:flutter/material.dart';
import '../../sso_client.dart';

class TenantsTab extends StatefulWidget {
  final SSOAdminClient client;
  const TenantsTab({super.key, required this.client});

  @override
  State<TenantsTab> createState() => _TenantsTabState();
}

class _TenantsTabState extends State<TenantsTab> {
  late Future<List<dynamic>> _future = widget.client.listTenants();
  String? _busyId;

  void _reload() => setState(() => _future = widget.client.listTenants());

  Future<void> _toggleStatus(String id, String currentStatus) async {
    final next = currentStatus == 'suspended' ? 'active' : 'suspended';
    setState(() => _busyId = id);
    try {
      await widget.client.setTenantStatus(id, next);
      _reload();
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tenant'),
        content: Text('Delete $label? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyId = id);
    try {
      await widget.client.deleteTenant(id);
      _reload();
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _TenantFormDialog(client: widget.client, existing: existing),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Tenants', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
              IconButton(onPressed: () => _openForm(), icon: const Icon(Icons.add)),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Center(child: Text('No tenants'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = items[i] as Map<String, dynamic>;
                  final id = t['id']?.toString() ?? '';
                  final status = t['status']?.toString() ?? 'active';
                  final suspended = status == 'suspended';
                  final busy = _busyId == id;
                  return ListTile(
                    leading: Icon(Icons.business, color: suspended ? Colors.redAccent : Colors.greenAccent),
                    title: Text(t['name']?.toString() ?? id),
                    subtitle: Text('${t['slug'] ?? ''} · $status'),
                    trailing: busy
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'toggle':
                                  _toggleStatus(id, status);
                                  break;
                                case 'edit':
                                  _openForm(existing: t);
                                  break;
                                case 'delete':
                                  _delete(id, t['name']?.toString() ?? id);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(suspended ? 'Activate' : 'Suspend'),
                              ),
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Create/edit form for a single tenant. `existing` is null for create;
/// when editing, `id` is fixed and `status` is intentionally omitted from
/// both the UI and the submitted body (status changes flow only through
/// the Suspend/Activate control, matching the server's Update semantics).
class _TenantFormDialog extends StatefulWidget {
  final SSOAdminClient client;
  final Map<String, dynamic>? existing;
  const _TenantFormDialog({required this.client, this.existing});

  @override
  State<_TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<_TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _slugController;
  late final TextEditingController _nameController;
  String _status = 'active';
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idController = TextEditingController(text: e?['id']?.toString() ?? '');
    _slugController = TextEditingController(text: e?['slug']?.toString() ?? '');
    _nameController = TextEditingController(text: e?['name']?.toString() ?? '');
  }

  @override
  void dispose() {
    _idController.dispose();
    _slugController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'slug': _slugController.text,
        'name': _nameController.text,
      };
      if (_isEdit) {
        await widget.client.updateTenant(_idController.text, body);
      } else {
        body['id'] = _idController.text;
        body['status'] = _status;
        await widget.client.createTenant(body);
      }
      if (mounted) Navigator.pop(context, true);
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit tenant' : 'New tenant'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _idController,
                enabled: !_isEdit,
                decoration: const InputDecoration(labelText: 'ID'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(labelText: 'Slug'),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('active')),
                    DropdownMenuItem(value: 'suspended', child: Text('suspended')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
