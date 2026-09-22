import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_execution_lease_checkpoint.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Renders a validated execution-lease restart image as local metadata.
///
/// The card intentionally omits fencing tokens, terminal proofs, receipt
/// digests, and reason text. It has no target selector, reservation action,
/// dispatch callback, process output, or authority path.
class ForgeExecutionLeaseCheckpointPreviewCard extends StatelessWidget {
  final ForgeExecutionLeaseCheckpointFixture fixture;

  const ForgeExecutionLeaseCheckpointPreviewCard({
    super.key,
    required this.fixture,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('forge-execution-lease-checkpoint-preview-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Execution lease checkpoint local preview'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Restart metadata only; no lease is restored and no Runner is contacted.',
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
              _valueRow(
                context,
                'Attempt ID',
                fixture.cases.first.checkpoint.grant.attemptID,
              ),
              _valueRow(
                context,
                'Target declaration',
                fixture.cases.first.checkpoint.grant.targetID,
              ),
              _valueRow(
                context,
                'Epoch',
                '${fixture.cases.first.checkpoint.grant.epoch}',
              ),
              _valueRow(
                context,
                'Issued at (ms)',
                '${fixture.cases.first.checkpoint.grant.issuedAtMS}',
              ),
              _valueRow(
                context,
                'Expires at (ms)',
                '${fixture.cases.first.checkpoint.grant.expiresAtMS}',
              ),
            ]),
            _section(context, 'Checkpoint outcomes', [
              for (final item in fixture.cases)
                ListTile(
                  key: ValueKey(
                    'forge-execution-lease-checkpoint-case-${item.name}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item.name),
                  subtitle: Text(_caseSummary(item)),
                ),
            ]),
            _section(context, 'Authority boundary', [
              for (final row in const [
                ('Lease issued', false),
                ('Terminal persisted', false),
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

  String _caseSummary(ForgeExecutionLeaseCheckpointCase item) {
    final expected = item.expected;
    if (!expected.accepted) {
      return 'accepted=false error=${expected.error ?? 'invalid_checkpoint'}';
    }
    return 'accepted=true terminal=${expected.terminal} uncertain=${expected.uncertain}';
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
