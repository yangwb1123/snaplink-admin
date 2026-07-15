import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../sso_client.dart';

class ClientsTab extends StatefulWidget {
  final SSOAdminClient client;
  const ClientsTab({super.key, required this.client});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  late Future<List<dynamic>> _future = widget.client.listClients();

  void _reload() => setState(() => _future = widget.client.listClients());

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _ClientFormDialog(client: widget.client),
    );
    if (created == true) _reload();
  }

  Future<void> _openEditDialog(Map<String, dynamic> c) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _ClientFormDialog(client: widget.client, existing: c),
    );
    if (updated == true) _reload();
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text('Delete $id? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.deleteClient(id);
      if (!mounted) return;
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rotateSecret(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    String secret;
    try {
      secret = await widget.client.rotateClientSecret(id);
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New client secret'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This secret will not be shown again.'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SelectableText(secret)),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: secret));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
              Text('Clients', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(onPressed: _openCreateDialog, icon: const Icon(Icons.add)),
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
                return const Center(child: Text('No clients'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = items[i] as Map<String, dynamic>;
                  final active = c['active'] == true;
                  return ListTile(
                    leading: Icon(Icons.apps, color: active ? Colors.greenAccent : Colors.grey),
                    title: Text(c['id']?.toString() ?? '?'),
                    subtitle: Text(c['name']?.toString() ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c['tokenStrategy']?.toString() ?? c['token_strategy']?.toString() ?? ''),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _openEditDialog(c);
                                break;
                              case 'rotate':
                                _rotateSecret(c);
                                break;
                              case 'delete':
                                _confirmDelete(c);
                                break;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'rotate', child: Text('Rotate secret')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
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

/// Create/edit form for an [AdminClient]. Pass [existing] to edit; omit to create.
class _ClientFormDialog extends StatefulWidget {
  final SSOAdminClient client;
  final Map<String, dynamic>? existing;

  const _ClientFormDialog({required this.client, this.existing});

  bool get isEdit => existing != null;

  @override
  State<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<_ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _redirectUrisController;
  late final TextEditingController _allowedScopesController;
  late final TextEditingController _secretController;
  String _tokenStrategy = 'jwt';
  bool _active = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _idController = TextEditingController(text: existing?['id']?.toString() ?? '');
    _nameController = TextEditingController(text: existing?['name']?.toString() ?? '');
    _redirectUrisController = TextEditingController(text: _joinList(existing?['redirect_uris']));
    _allowedScopesController = TextEditingController(text: _joinList(existing?['allowed_scopes']));
    _secretController = TextEditingController();
    final strategy = existing?['token_strategy']?.toString() ?? existing?['tokenStrategy']?.toString();
    if (strategy == 'jwt' || strategy == 'session') _tokenStrategy = strategy!;
    _active = existing?['active'] == true || existing == null;
  }

  static String _joinList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).join('\n');
    return '';
  }

  static List<String> _splitList(String text) => text
      .split(RegExp(r'[,\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _redirectUrisController.dispose();
    _allowedScopesController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'name': _nameController.text.trim(),
      'redirect_uris': _splitList(_redirectUrisController.text),
      'allowed_scopes': _splitList(_allowedScopesController.text),
      'token_strategy': _tokenStrategy,
      'active': _active,
    };
    final secret = _secretController.text.trim();
    if (secret.isNotEmpty) body['secret'] = secret;
    try {
      if (widget.isEdit) {
        final id = widget.existing!['id'].toString();
        await widget.client.updateClient(id, body);
      } else {
        body['id'] = _idController.text.trim();
        await widget.client.createClient(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on SSOError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit client' : 'New client'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _idController,
                enabled: !widget.isEdit,
                decoration: const InputDecoration(labelText: 'ID'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _redirectUrisController,
                decoration: const InputDecoration(
                  labelText: 'Redirect URIs',
                  helperText: 'One per line or comma-separated',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _allowedScopesController,
                decoration: const InputDecoration(
                  labelText: 'Allowed scopes',
                  helperText: 'One per line or comma-separated',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _tokenStrategy,
                decoration: const InputDecoration(labelText: 'Token strategy'),
                items: const [
                  DropdownMenuItem(value: 'jwt', child: Text('jwt')),
                  DropdownMenuItem(value: 'session', child: Text('session')),
                ],
                onChanged: (v) => setState(() => _tokenStrategy = v ?? 'jwt'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Secret (optional)',
                  helperText: 'Leave blank for a public PKCE client. Only set this to configure a '
                      'static secret directly — you can also mint one afterward via Rotate Secret.',
                  helperMaxLines: 3,
                ),
                obscureText: true,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
