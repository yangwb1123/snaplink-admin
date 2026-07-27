import 'dart:convert';

import 'package:flutter/material.dart';

class NetworkPolicyDraft {
  final String name;
  final List<String> cidrs;
  final List<String> hostnames;
  final int priority;
  final String advertisedBaseUrl;
  final String advertisedJwksUrl;
  final String advertisedLogoutUrl;
  final Map<String, String> metadata;

  const NetworkPolicyDraft({
    required this.name,
    required this.cidrs,
    required this.hostnames,
    required this.priority,
    required this.advertisedBaseUrl,
    required this.advertisedJwksUrl,
    required this.advertisedLogoutUrl,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'cidrs': cidrs,
    'hostnames': hostnames,
    'priority': priority,
    if (advertisedBaseUrl.isNotEmpty) 'advertised_base_url': advertisedBaseUrl,
    if (advertisedJwksUrl.isNotEmpty) 'advertised_jwks_url': advertisedJwksUrl,
    if (advertisedLogoutUrl.isNotEmpty)
      'advertised_logout_url': advertisedLogoutUrl,
    'metadata': metadata,
  };
}

class NetworkPolicyDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const NetworkPolicyDialog({super.key, this.existing});

  @override
  State<NetworkPolicyDialog> createState() => _NetworkPolicyDialogState();
}

class _NetworkPolicyDialogState extends State<NetworkPolicyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cidrsCtrl;
  late final TextEditingController _hostnamesCtrl;
  late final TextEditingController _priorityCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _jwksUrlCtrl;
  late final TextEditingController _logoutUrlCtrl;
  late final TextEditingController _metadataCtrl;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final value = widget.existing ?? const <String, dynamic>{};
    _nameCtrl = TextEditingController(text: value['name']?.toString() ?? '');
    _cidrsCtrl = TextEditingController(text: _join(value['cidrs']));
    _hostnamesCtrl = TextEditingController(text: _join(value['hostnames']));
    _priorityCtrl = TextEditingController(
      text: value['priority']?.toString() ?? '0',
    );
    _baseUrlCtrl = TextEditingController(
      text: value['advertised_base_url']?.toString() ?? '',
    );
    _jwksUrlCtrl = TextEditingController(
      text: value['advertised_jwks_url']?.toString() ?? '',
    );
    _logoutUrlCtrl = TextEditingController(
      text: value['advertised_logout_url']?.toString() ?? '',
    );
    _metadataCtrl = TextEditingController(
      text: const JsonEncoder.withIndent(
        '  ',
      ).convert(value['metadata'] ?? const <String, String>{}),
    );
  }

  static String _join(Object? value) =>
      value is List ? value.map((item) => item.toString()).join('\n') : '';

  List<String> _split(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cidrsCtrl.dispose();
    _hostnamesCtrl.dispose();
    _priorityCtrl.dispose();
    _baseUrlCtrl.dispose();
    _jwksUrlCtrl.dispose();
    _logoutUrlCtrl.dispose();
    _metadataCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final raw = jsonDecode(
        _metadataCtrl.text.trim().isEmpty ? '{}' : _metadataCtrl.text,
      );
      if (raw is! Map) throw const FormatException();
      final metadata = <String, String>{
        for (final entry in raw.entries)
          entry.key.toString(): entry.value.toString(),
      };
      Navigator.pop(
        context,
        NetworkPolicyDraft(
          name: _nameCtrl.text.trim(),
          cidrs: _split(_cidrsCtrl.text),
          hostnames: _split(_hostnamesCtrl.text),
          priority: int.parse(_priorityCtrl.text.trim()),
          advertisedBaseUrl: _baseUrlCtrl.text.trim(),
          advertisedJwksUrl: _jwksUrlCtrl.text.trim(),
          advertisedLogoutUrl: _logoutUrlCtrl.text.trim(),
          metadata: metadata,
        ),
      );
    } on FormatException {
      setState(() => _error = 'Priority and metadata must be valid values.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_editing ? 'Edit network policy' : 'Create network policy'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                enabled: !_editing,
                decoration: const InputDecoration(labelText: 'Policy name'),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cidrsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'CIDR ranges',
                  helperText: 'One per line, for example 10.0.0.0/8.',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _hostnamesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Hostnames',
                  helperText: 'Hostname matches take precedence over CIDRs.',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priorityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Priority'),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? 'Enter an integer'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _baseUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Advertised base URL',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _jwksUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Advertised JWKS URL',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _logoutUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Advertised logout URL',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _metadataCtrl,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(labelText: 'Metadata JSON'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Apply policy')),
    ],
  );
}
