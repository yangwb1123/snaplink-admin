import 'package:flutter/material.dart';

import '../../api/forge_preflight_fixture.dart';

/// Renders a validated local Forge fixture. It intentionally has no callbacks
/// or clients: a preview card cannot dispatch work.
class ForgePreflightFixtureCard extends StatelessWidget {
  final ForgePreflightFixture fixture;

  const ForgePreflightFixtureCard({super.key, required this.fixture});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forge preflight preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _row('Run', '${fixture.runId} · ${fixture.runStatus}'),
          _row('Attempt', '${fixture.attemptId} · ${fixture.attemptState}'),
          _row(
            'Lease',
            'epoch ${fixture.leaseEpoch} · ${fixture.leaseActive ? 'active' : 'inactive'}',
          ),
          _row(
            'Preflight',
            '${fixture.declarativeReadyCount}/${fixture.candidateCount} ready · ${fixture.declarativePreflightReady ? 'ready' : 'blocked'}',
          ),
          _row('Target', fixture.intentTargetId),
          _row('Selected target', fixture.selectedTargetId ?? 'none'),
          _row('Evaluated', '${fixture.evaluatedAtMs} ms'),
          _row(
            'Authority',
            fixture.authority.values.every((value) => !value)
                ? 'none issued'
                : 'invalid',
          ),
          const SizedBox(height: 8),
          const Text('Preview only · no dispatch performed'),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 132, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
