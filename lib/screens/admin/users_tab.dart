import 'package:flutter/material.dart';
import '../../sso_client.dart';

class UsersTab extends StatefulWidget {
  final SSOAdminClient client;
  const UsersTab({super.key, required this.client});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  late Future<List<dynamic>> _future = widget.client.listUsers();

  void _reload() => setState(() => _future = widget.client.listUsers());

  Future<void> _openCreateDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserFormDialog(client: widget.client),
    );
    if (result != null) _reload();
  }

  Future<void> _openEditDialog(Map<String, dynamic> user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserFormDialog(client: widget.client, existing: user),
    );
    if (result != null) _reload();
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Delete $id? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.deleteUser(id);
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
              Text('Users', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
              ),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
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
                return const Center(child: Text('No users'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = items[i] as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(u['id']?.toString() ?? '?'),
                    subtitle: Text('provider: ${u['provider'] ?? '?'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          u['externalId']?.toString() ??
                              u['external_id']?.toString() ??
                              '',
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _openEditDialog(u);
                            if (value == 'delete') _confirmDelete(u);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
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

/// Create/edit form for an [AdminUser]. Reused for both flows: [existing]
/// null means create (the id field is editable and required); non-null means
/// edit (id is fixed, shown disabled, and used only to address the update
/// call).
class _UserFormDialog extends StatefulWidget {
  final SSOAdminClient client;
  final Map<String, dynamic>? existing;

  const _UserFormDialog({required this.client, this.existing});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _externalIdController;
  late final TextEditingController _providerController;
  late final TextEditingController _attributesController;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _idController = TextEditingController(text: u?['id']?.toString() ?? '');
    _externalIdController = TextEditingController(
      text:
          u?['external_id']?.toString() ?? u?['externalId']?.toString() ?? '',
    );
    _providerController = TextEditingController(
      text: u?['provider']?.toString() ?? '',
    );
    _attributesController = TextEditingController(
      text: _attributesToText(u?['attributes']),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _externalIdController.dispose();
    _providerController.dispose();
    _attributesController.dispose();
    super.dispose();
  }

  static String _attributesToText(dynamic attributes) {
    if (attributes is Map) {
      return attributes.entries.map((e) => '${e.key}=${e.value}').join('\n');
    }
    return '';
  }

  static Map<String, String> _parseAttributes(String text) {
    final result = <String, String>{};
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final idx = trimmed.indexOf('=');
      if (idx <= 0) continue;
      result[trimmed.substring(0, idx).trim()] = trimmed
          .substring(idx + 1)
          .trim();
    }
    return result;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'external_id': _externalIdController.text.trim(),
      'provider': _providerController.text.trim(),
      'attributes': _parseAttributes(_attributesController.text),
    };
    try {
      Map<String, dynamic> result;
      if (_isEditing) {
        result = await widget.client.updateUser(
          _idController.text.trim(),
          body,
        );
      } else {
        body['id'] = _idController.text.trim();
        result = await widget.client.createUser(body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on SSOError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit User' : 'New User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _idController,
                enabled: !_isEditing,
                decoration: const InputDecoration(labelText: 'ID'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _externalIdController,
                decoration: const InputDecoration(labelText: 'External ID'),
              ),
              TextFormField(
                controller: _providerController,
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
              TextFormField(
                controller: _attributesController,
                decoration: const InputDecoration(
                  labelText: 'Attributes (one key=value per line)',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
