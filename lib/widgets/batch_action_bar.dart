import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

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
          Icon(
            Icons.checklist,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            context.tr('{count} selected', {'count': selectedCount}),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: isLoading ? null : onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.strings.delete),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          TextButton(
            onPressed: isLoading ? null : onClearSelection,
            child: Text(context.tr('Clear')),
          ),
        ],
      ),
    );
  }
}
