import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import '../../api/forge_conversations_models.dart';

/// Displays the server's execution-consent metadata preview. The card has no
/// consent, Run, device, scheduling, or dispatch action.
class ForgeExecutionConsentPreviewCard extends StatelessWidget {
  final ForgeExecutionConsentPreview preview;

  const ForgeExecutionConsentPreviewCard({super.key, required this.preview});

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-execution-consent-preview-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'Execution consent preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const LocalizedText(
            'Preview only · consent has not been granted; no Run or device was selected.',
          ),
          const SizedBox(height: 12),
          _row('Conversation', preview.conversationID),
          _row('Project', preview.projectID),
          _row('Profile', preview.profileID),
          _row('Profile SHA-256', preview.profileSHA256),
          _row('Maximum TTL', '${preview.maximumTTLMS} ms'),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
