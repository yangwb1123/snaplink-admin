import 'package:flutter/material.dart';

/// Responsive title and primary actions for admin collection pages.
class AdminListHeader extends StatelessWidget {
  final String title;
  final String createTooltip;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const AdminListHeader({
    super.key,
    required this.title,
    required this.createTooltip,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        OverflowBar(
          spacing: 4,
          children: [
            IconButton(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              tooltip: createTooltip,
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ],
    ),
  );
}
