import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import '../admin_module_groups.dart';

class ConnectionCreateCard extends StatelessWidget {
  final TextEditingController idController;
  final TextEditingController tenantController;
  final TextEditingController displayNameController;
  final TextEditingController domainsController;
  final TextEditingController configController;
  final String type;
  final bool enabled;
  final bool mutating;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onSave;

  const ConnectionCreateCard({
    super.key,
    required this.idController,
    required this.tenantController,
    required this.displayNameController,
    required this.domainsController,
    required this.configController,
    required this.type,
    required this.enabled,
    required this.mutating,
    required this.onTypeChanged,
    required this.onEnabledChanged,
    required this.onSave,
  });

  /// 模块强调色（connections → security 组 rose）。
  Color get _accent => adminModuleIconColor('connections');

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.add_link, size: 20, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: LocalizedText(
                  'Create or replace connection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const LocalizedText(
            'Saving an existing ID replaces its configuration and domain routing.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: idController,
            decoration: InputDecoration(labelText: 'Connection ID'.localized),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tenantController,
            decoration: InputDecoration(labelText: 'Tenant ID'.localized),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: 'Protocol'.localized),
            items: const [
              DropdownMenuItem(value: 'oidc', child: LocalizedText('OIDC')),
              DropdownMenuItem(value: 'saml', child: LocalizedText('SAML')),
            ],
            onChanged: mutating
                ? null
                : (value) => onTypeChanged(value ?? type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: displayNameController,
            decoration: InputDecoration(labelText: 'Display name'.localized),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: domainsController,
            decoration: InputDecoration(
              labelText: 'Email domains'.localized,
              hintText: 'example.com, subsidiary.example.com'.localized,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LocalizedText('Connection enabled'),
            value: enabled,
            onChanged: mutating ? null : onEnabledChanged,
          ),
          TextField(
            controller: configController,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'Protocol configuration (JSON)'.localized,
              hintText: '{"oidc_issuer":"https://idp.example.com"}'.localized,
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: mutating ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: const LocalizedText('Save connection'),
          ),
        ],
      ),
    ),
  );
}
