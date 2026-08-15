import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

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
    title: LocalizedText(
      _editing ? 'Edit network policy' : 'Create network policy',
    ),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                enabled: !_editing,
                autofocus: !_editing,
                decoration: InputDecoration(labelText: 'Policy name'.localized),
                validator: (value) => value?.trim().isEmpty == true
                    ? context.tr('Required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cidrsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'CIDR ranges'.localized,
                  helperText: 'One per line, for example 10.0.0.0/8.'.localized,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hostnamesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Hostnames'.localized,
                  helperText:
                      'Hostname matches take precedence over CIDRs.'.localized,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priorityCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Priority'.localized,
                  helperText: 'Lower values are evaluated first.'.localized,
                ),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? context.tr('Enter an integer')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baseUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Advertised base URL'.localized,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jwksUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Advertised JWKS URL'.localized,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _logoutUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Advertised logout URL'.localized,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _metadataCtrl,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Metadata JSON'.localized,
                  helperText: 'Must be a JSON object.'.localized,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                LocalizedText(
                  _error!,
                  // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                  style: TextStyle(
                    color: AppColors.semanticFor(
                      Theme.of(context).brightness,
                      AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const LocalizedText('Apply policy'),
      ),
    ],
  );
}
