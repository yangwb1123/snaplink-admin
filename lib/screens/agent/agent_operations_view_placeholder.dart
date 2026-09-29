part of 'agent_operations_view.dart';

class _SelectSessionPlaceholder extends StatelessWidget {
  const _SelectSessionPlaceholder();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            context.tr('Select an instance or session to view Agent activity.'),
          ),
        ],
      ),
    ),
  );
}
