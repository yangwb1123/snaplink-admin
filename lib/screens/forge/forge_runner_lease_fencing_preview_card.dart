import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_runner_lease_fencing.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Renders a file-backed Runner lease/fencing contract as local metadata.
///
/// The card intentionally omits fencing tokens, receipt digests and terminal
/// reasons. It has no target selector, reservation action, dispatch callback,
/// process output or authority path.
class ForgeRunnerLeaseFencingPreviewCard extends StatelessWidget {
  final ForgeRunnerLeaseFencingFixture fixture;

  const ForgeRunnerLeaseFencingPreviewCard({super.key, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('forge-runner-lease-fencing-preview-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Runner lease/fencing local preview'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'File-backed metadata only; no lease is acquired and no Runner is contacted.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Contract', [
              _valueRow(context, 'Schema', fixture.schemaVersion),
              _valueRow(context, 'Evaluation mode', fixture.evaluationMode),
              _valueRow(context, 'Cases', '${fixture.cases.length}'),
              _valueRow(context, 'Authority', 'offline'),
            ]),
            _section(context, 'Lease metadata', [
              _valueRow(context, 'Attempt ID', fixture.grant.attemptID),
              _valueRow(context, 'Target declaration', fixture.grant.targetID),
              _valueRow(context, 'Epoch', '${fixture.grant.epoch}'),
              _valueRow(
                context,
                'Issued at (ms)',
                '${fixture.grant.issuedAtMS}',
              ),
              _valueRow(
                context,
                'Expires at (ms)',
                '${fixture.grant.expiresAtMS}',
              ),
            ]),
            _section(context, 'Case outcomes', [
              for (final item in fixture.cases)
                ListTile(
                  key: ValueKey('forge-runner-lease-case-${item.name}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item.name),
                  subtitle: Text(_caseSummary(item)),
                ),
            ]),
            _section(context, 'Authority boundary', [
              for (final row in const [
                ('Device identity verified', false),
                ('Command persisted', false),
                ('Reservation created', false),
                ('Execution authorized', false),
                ('Dispatch performed', false),
                ('Audit published', false),
              ])
                _valueRow(context, row.$1, '${row.$2}'),
            ]),
          ],
        ),
      ),
    );
  }

  String _caseSummary(ForgeRunnerLeaseCase item) {
    final expected = item.expected;
    if (item.operation == 'active') {
      return '${item.operation} · active=${expected.active}';
    }
    if (expected.accepted) {
      final epoch = expected.epoch == null ? '' : ' · epoch=${expected.epoch}';
      final replayed = expected.replayed == true ? ' · replayed=true' : '';
      return '${item.operation} · accepted$epoch$replayed';
    }
    return '${item.operation} · rejected';
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(title),
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
        SizedBox(width: 210, child: Text(context.tr(label))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
