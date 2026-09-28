import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';

/// Renders the planning-only scheduler-selection projection. The panel
/// deliberately has no select, reserve, lease, or dispatch action.
class ForgeSchedulerSelectionPreviewPanel extends StatelessWidget {
  final ForgeSchedulerSelectionPreview preview;

  const ForgeSchedulerSelectionPreviewPanel({super.key, required this.preview});

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-preview-panel'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'Scheduler selection preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const LocalizedText(
            'Planning-only preview. It explains one deterministic candidate and grants no lease or execution authority.',
          ),
          _row('Conversation', preview.conversationID),
          _row('Run / Attempt', '${preview.runID} / ${preview.attemptID}'),
          _row('Evaluated at', '${preview.evaluatedAtMS}'),
          _row('Candidates', '${preview.candidateCount}'),
          _row('Eligible', '${preview.eligibleCandidateCount}'),
          _row(
            'Selected',
            preview.selectionAvailable
                ? '${preview.selectedDeviceID} / ${preview.selectedInstanceID}'
                : 'none',
          ),
          _row('Reason', preview.selectionReason),
          _row('Owner', '${preview.owner.subject} · ${preview.owner.tenantID}'),
          _row('Authority', 'all false · preview-only'),
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
