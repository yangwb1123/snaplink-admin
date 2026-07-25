import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create or replace connection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Saving an existing ID replaces its configuration and domain routing.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: idController,
            decoration: const InputDecoration(labelText: 'Connection ID'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: tenantController,
            decoration: const InputDecoration(labelText: 'Tenant ID'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Protocol'),
            items: const [
              DropdownMenuItem(value: 'oidc', child: Text('OIDC')),
              DropdownMenuItem(value: 'saml', child: Text('SAML')),
            ],
            onChanged: mutating
                ? null
                : (value) => onTypeChanged(value ?? type),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: displayNameController,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: domainsController,
            decoration: const InputDecoration(
              labelText: 'Email domains',
              hintText: 'example.com, subsidiary.example.com',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Connection enabled'),
            value: enabled,
            onChanged: mutating ? null : onEnabledChanged,
          ),
          TextField(
            controller: configController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Protocol configuration (JSON)',
              hintText: '{"oidc_issuer":"https://idp.example.com"}',
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: mutating ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save connection'),
          ),
        ],
      ),
    ),
  );
}
