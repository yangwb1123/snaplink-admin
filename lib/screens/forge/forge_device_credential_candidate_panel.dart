import 'package:flutter/material.dart';

import 'package:sso_admin/api/forge_device_credential_candidate.dart';

/// Displays the injected credential lifecycle candidate without exposing a
/// mutation control or treating metadata as a usable credential. The panel is
/// intentionally value-only so the same projection can be used by Web, App,
/// and Mobile surfaces.
class ForgeDeviceCredentialCandidatePanel extends StatelessWidget {
  final ForgeDeviceCredentialLifecycleCandidate candidate;

  ForgeDeviceCredentialCandidatePanel({super.key, required this.candidate})
    : assert(candidate.isDisplayOnly);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('forge-device-credential-candidate-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Device credential lifecycle candidate',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Metadata-only preview; no credential material or execution authority.',
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Envelope', [
              _valueRow(context, 'Schema', candidate.schemaVersion),
              _valueRow(context, 'Owner', candidate.owner.subject),
              _valueRow(context, 'Tenant', candidate.owner.tenantID),
              _valueRow(context, 'Device', candidate.deviceID),
              _valueRow(context, 'Action', candidate.action),
              _valueRow(context, 'Revision', '${candidate.revision}'),
            ]),
            _section(context, 'Next metadata', [
              _valueRow(context, 'Credential', candidate.next.credentialID),
              _valueRow(context, 'Key', candidate.next.keyID),
              _valueRow(context, 'State', candidate.next.credentialState),
              _valueRow(
                context,
                'Generation',
                '${candidate.next.keyGeneration}',
              ),
              _valueRow(
                context,
                'Validity',
                '${candidate.next.issuedAtMS}–${candidate.next.expiresAtMS} ms',
              ),
            ]),
            _section(context, 'Authority', [
              _valueRow(context, 'Preview only', '${candidate.previewOnly}'),
              _valueRow(
                context,
                'Candidate published',
                '${candidate.candidatePublished}',
              ),
              _valueRow(context, 'Authority', 'all false'),
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
        SizedBox(width: 140, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
