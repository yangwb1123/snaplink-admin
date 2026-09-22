import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';

/// Renders caller-injected client/session metadata without creating an
/// authority or network boundary.
///
/// The panel deliberately has no reader, callbacks, or action controls. A
/// caller must decode the canonical fixture before constructing it, so the
/// shared Forge Sessions screen remains request-free by default.
class ForgeClientInstanceSessionViewPanel extends StatelessWidget {
  final ForgeClientInstanceSessionView fixture;

  ForgeClientInstanceSessionViewPanel({super.key, required this.fixture})
    : assert(fixture.isDisplayOnly);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('forge-client-instance-session-view-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Client instance session view',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Read-only metadata; no Prompt or device authority.',
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Owner declaration', [
              _valueRow(context, 'Issuer', fixture.owner.issuer),
              _valueRow(context, 'Subject', fixture.owner.subject),
              _valueRow(context, 'Tenant', fixture.owner.tenantID),
              _valueRow(context, 'Authority', 'offline'),
            ]),
            _section(context, 'Client instances', [
              for (final instance in fixture.instances)
                ListTile(
                  key: ValueKey(
                    'forge-client-instance-session-view-${instance.instanceID}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(instance.instanceID),
                  subtitle: Text(
                    '${instance.clientKind} · ${instance.status} · '
                    'observed=${instance.observedAtMS} · '
                    'sessions=${instance.sessionIDs.join(', ')}',
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      );

  Widget _valueRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
