import 'package:flutter/material.dart';
import 'package:sso_admin/api/sso_client.dart';

/// Create/edit form for a single tenant. `existing` is null for create;
/// when editing, `id` is fixed and `status` is intentionally omitted from
/// both the UI and the submitted body (status changes flow only through
/// the Suspend/Activate control, matching the server's Update semantics).
class TenantFormDialog extends StatefulWidget {
  final SSOAdminClient client;
  final Map<String, dynamic>? existing;
  const TenantFormDialog({super.key, required this.client, this.existing});

  @override
  State<TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<TenantFormDialog> {
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
        final e = widget.existing!;
        if (e['settings'] != null) body['settings'] = e['settings'];
        if (e['home_region'] != null) body['home_region'] = e['home_region'];
        if (e['allowed_regions'] != null) {
          body['allowed_regions'] = e['allowed_regions'];
        }
        if (e['enforce_writes'] != null) {
          body['enforce_writes'] = e['enforce_writes'];
        }
        await widget.client.updateTenant(_idController.text, body);
      } else {
        body['id'] = _idController.text;
        body['status'] = _status;
        await widget.client.createTenant(body);
      }
      if (mounted) Navigator.pop(context, true);
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('suspended'),
                    ),
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
