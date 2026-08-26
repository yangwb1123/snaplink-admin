part of 'user_detail_widgets.dart';

/// Lifecycle is a small vertical timeline of current state and transitions.
class UserLifecycleView extends StatelessWidget {
  final Map<String, dynamic> lifecycle;
  final bool showBackButton;
  final VoidCallback onBack;
  const UserLifecycleView({
    super.key,
    required this.lifecycle,
    required this.showBackButton,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final state = lifecycle['state']?.toString() ?? 'active';
    final transitions =
        (lifecycle['allowed_transitions'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _resourceCard(
          context,
          title: 'Account lifecycle',
          icon: Icons.route,
          children: [
            _timelineStep(
              context,
              icon: Icons.radio_button_checked,
              isLast: transitions.isEmpty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    'Current state: {state}',
                    args: {'state': state},
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  StatusChip.info(label: state),
                ],
              ),
            ),
            if (transitions.isNotEmpty)
              _timelineStep(
                context,
                icon: Icons.alt_route,
                isLast: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalizedText('Allowed transitions:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _transitionWidgets(transitions),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (showBackButton) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const LocalizedText('Back to user list'),
          ),
        ],
      ],
    );
  }
}

List<Widget> _transitionWidgets(List<String> transitions) => [
  for (final transition in transitions)
    Tooltip(
      message: transition,
      child: Chip(
        label: Text(transition, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ),
];

Widget _timelineStep(
  BuildContext context, {
  required IconData icon,
  required bool isLast,
  required Widget child,
}) {
  final line = Theme.of(context).colorScheme.outlineVariant;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 32,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (!isLast)
              Positioned(
                top: 16,
                bottom: 0,
                child: Container(width: 2, color: line),
              ),
            Icon(icon, size: 22, color: _userAccent()),
          ],
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
          child: child,
        ),
      ),
    ],
  );
}
