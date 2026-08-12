import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'admin_module_groups.dart';

/// 权限模块组色（identity → indigo-violet）。
Color _accent() => adminModuleIconColor('permissions');

class PermissionsClientSelector extends StatelessWidget {
  final TextEditingController controller;
  final String? clientId;
  final bool loading;
  final VoidCallback onSearch;
  final VoidCallback onSubmitted;

  const PermissionsClientSelector({
    super.key,
    required this.controller,
    required this.clientId,
    required this.loading,
    required this.onSearch,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Client ID'.localized,
              hintText: 'Enter client ID and press Search'.localized,
              prefixIcon: Icon(
                Icons.business_outlined,
                size: 18,
                color: accent,
              ),
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: loading ? null : onSearch,
          icon: const Icon(Icons.search, size: 18),
          label: const LocalizedText('Search'),
        ),
        if (clientId case final value?) ...[
          const SizedBox(width: 12),
          Chip(
            avatar: Icon(Icons.check_circle, size: 16, color: accent),
            label: Text(value),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}

class PermissionMenusCard extends StatelessWidget {
  final TextEditingController controller;
  final bool mutating;
  final VoidCallback onSave;

  const PermissionMenusCard({
    super.key,
    required this.controller,
    required this.mutating,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(Icons.account_tree_outlined, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LocalizedText(
                    'Navigation tree (JSON)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Menu tree'.localized,
              ),
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: mutating ? null : onSave,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const LocalizedText('Save menus'),
            ),
          ],
        ),
      ),
    );
  }
}
