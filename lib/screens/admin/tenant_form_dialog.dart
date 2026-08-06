import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/sso_client.dart';

import 'tenant_residency_fields.dart';

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
  late final TextEditingController _homeRegionController;
  late final TextEditingController _allowedRegionsController;
  String _status = 'active';
  bool _enforceWrites = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idController = TextEditingController(text: e?['id']?.toString() ?? '');
    _slugController = TextEditingController(text: e?['slug']?.toString() ?? '');
    _nameController = TextEditingController(text: e?['name']?.toString() ?? '');
    _homeRegionController = TextEditingController(
      text: e?['home_region']?.toString() ?? '',
    );
    _allowedRegionsController = TextEditingController(
      text: _joinList(e?['allowed_regions']),
    );
    _enforceWrites = e?['enforce_writes'] == true;
  }

  static String _joinList(dynamic value) =>
      value is List ? value.map((item) => item.toString()).join('\n') : '';

  @override
  void dispose() {
    _idController.dispose();
    _slugController.dispose();
    _nameController.dispose();
    _homeRegionController.dispose();
    _allowedRegionsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'slug': _slugController.text.trim(),
        'name': _nameController.text.trim(),
        'home_region': _homeRegionController.text.trim(),
        'allowed_regions': parseTenantRegions(_allowedRegionsController.text),
        'enforce_writes': _enforceWrites,
      };
      if (_isEdit) {
        final e = widget.existing!;
        if (e['settings'] != null) body['settings'] = e['settings'];
        await widget.client.updateTenant(_idController.text, body);
      } else {
        body['id'] = _idController.text.trim();
        body['status'] = _status;
        await widget.client.createTenant(body);
      }
      if (mounted) Navigator.pop(context, true);
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LocalizedText('Failed: {e}', args: {'e': e})));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: LocalizedText(_isEdit ? 'Edit tenant' : 'New tenant'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _idController,
                enabled: !_isEdit,
                decoration: InputDecoration(labelText: 'ID'.localized),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _slugController,
                decoration: InputDecoration(labelText: 'Slug'.localized),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'.localized),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: InputDecoration(labelText: 'Status'.localized),
                  items: const [
                    DropdownMenuItem(
                      value: 'active',
                      child: LocalizedText('active'),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: LocalizedText('suspended'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
              ],
              TenantResidencyFields(
                homeRegionController: _homeRegionController,
                allowedRegionsController: _allowedRegionsController,
                enforceWrites: _enforceWrites,
                onEnforceWritesChanged: (value) {
                  setState(() => _enforceWrites = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const LocalizedText('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : LocalizedText(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
