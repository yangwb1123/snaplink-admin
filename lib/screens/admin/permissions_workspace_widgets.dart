import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 300,
        child: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Client ID',
            hintText: 'Enter client ID and press Search',
          ),
          onSubmitted: (_) => onSubmitted(),
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: loading ? null : onSearch,
        child: const Text('Search'),
      ),
      if (clientId case final value?) ...[
        const SizedBox(width: 8),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ],
  );
}

class PermissionSectionSelector extends StatelessWidget {
  final String selectedSection;
  final ValueChanged<String> onSelected;

  const PermissionSectionSelector({
    super.key,
    required this.selectedSection,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final section in const [
          ('all', 'All'),
          ('roles', 'Roles'),
          ('assignments', 'Assignments'),
          ('menus', 'Menus'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(section.$2),
              selected: selectedSection == section.$1,
              onSelected: (_) => onSelected(section.$1),
            ),
          ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Navigation tree (JSON)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: mutating ? null : onSave,
            child: const Text('Save menus'),
          ),
        ],
      ),
    ),
  );
}
