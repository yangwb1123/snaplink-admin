import 'package:flutter/material.dart';

/// A floating action bar for batch operations on list selections.
///
/// Shows the count of selected items and action buttons when items are selected.
class BatchActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onDelete;
  final VoidCallback onClearSelection;
  final bool isLoading;

  const BatchActionBar({
    super.key,
    required this.selectedCount,
    required this.onDelete,
    required this.onClearSelection,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.checklist, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('$selectedCount selected',
              style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          TextButton.icon(
            onPressed: isLoading ? null : onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
          TextButton(
            onPressed: isLoading ? null : onClearSelection,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
