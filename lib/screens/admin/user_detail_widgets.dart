import 'package:flutter/material.dart';

class UserDetailHeader extends StatelessWidget {
  final Map<String, dynamic>? user;

  const UserDetailHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.person, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?['id']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Provider: ${user?['provider'] ?? ''}'),
                Text(
                  'External ID: '
                  '${user?['externalId'] ?? user?['external_id'] ?? ''}',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class UserDetailTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const UserDetailTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selectedIndex == i,
              onSelected: (_) => onSelected(i),
            ),
          ),
      ],
    ),
  );
}

class UserSessionsView extends StatelessWidget {
  final List<dynamic> sessions;

  const UserSessionsView({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: sessions.isEmpty
        ? [const Text('No active sessions')]
        : sessions
              .map(
                (session) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text(session['id']?.toString() ?? ''),
                    subtitle: Text(
                      'IP: ${session['ip'] ?? ''}  '
                      'UA: ${_truncatedUserAgent(session)}',
                    ),
                  ),
                ),
              )
              .toList(),
  );

  static String _truncatedUserAgent(dynamic session) {
    final userAgent = session['user_agent']?.toString() ?? '';
    return userAgent.substring(0, userAgent.length.clamp(0, 80));
  }
}

class UserConsentsView extends StatelessWidget {
  final List<dynamic> consents;
  final bool mutating;
  final ValueChanged<String> onRevoke;

  const UserConsentsView({
    super.key,
    required this.consents,
    required this.mutating,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: consents.isEmpty
        ? [const Text('No consents granted')]
        : consents
              .map(
                (consent) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.checklist),
                    title: Text(consent['client_id']?.toString() ?? ''),
                    subtitle: Text(
                      (consent['scopes'] as List?)?.join(', ') ?? '',
                    ),
                    trailing: TextButton(
                      onPressed: mutating
                          ? null
                          : () => onRevoke(
                              consent['client_id']?.toString() ?? '',
                            ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Revoke'),
                    ),
                  ),
                ),
              )
              .toList(),
  );
}

class UserMfaView extends StatelessWidget {
  final List<dynamic> factors;
  final bool mutating;
  final ValueChanged<String> onRemove;

  const UserMfaView({
    super.key,
    required this.factors,
    required this.mutating,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: factors.isEmpty
        ? [const Text('No MFA factors registered')]
        : factors
              .map(
                (factor) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.security),
                    title: Text(
                      factor['label']?.toString() ??
                          factor['method']?.toString() ??
                          '',
                    ),
                    subtitle: Text('Method: ${factor['method'] ?? ''}'),
                    trailing: TextButton(
                      onPressed: mutating
                          ? null
                          : () => onRemove(factor['id']?.toString() ?? ''),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ),
              )
              .toList(),
  );
}

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.route, size: 48, color: Colors.blue),
                const SizedBox(height: 8),
                Text(
                  'Current state: $state',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (transitions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Allowed transitions:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: transitions
                        .map((transition) => Chip(label: Text(transition)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showBackButton) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to user list'),
          ),
        ],
      ],
    );
  }
}
