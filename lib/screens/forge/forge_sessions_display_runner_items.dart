part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayRunnerItems on _ForgeSessionsScreenState {
  List<Widget> _runnerItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final runAttemptLeaseDispatchPreflight =
        display.runner.runAttemptLeaseDispatchPreflight;
    final runnerDispatchPlanPreview = display.runner.runnerDispatchPlanPreview;
    final runnerDispatchAdmission = display.runner.runnerDispatchAdmission;
    final runnerTransportAdmission = display.runner.runnerTransportAdmission;
    final runnerExecutionBoundary = display.runner.runnerExecutionBoundary;
    final runnerAttemptBoundary = display.runner.runnerAttemptBoundary;
    final localRunnerPreview = display.runner.localRunnerPreview;
    final executionConsentPreview = display.receipts.executionConsentPreview;
    return <Widget>[
      if (runAttemptLeaseDispatchPreflight != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgePreflightFixtureCard(
            fixture: runAttemptLeaseDispatchPreflight,
          ),
        ),
      if (runnerDispatchPlanPreview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeRunnerDispatchPlanPreviewCard(
            key: const ValueKey('forge-runner-dispatch-plan-preview-card'),
            preview: runnerDispatchPlanPreview,
          ),
        ),
      if (runnerDispatchAdmission != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeRunnerDispatchAdmissionCard(
            admission: runnerDispatchAdmission,
          ),
        ),
      if (runnerTransportAdmission != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeRunnerTransportAdmissionCard(
            admission: runnerTransportAdmission,
          ),
        ),
      if (runnerExecutionBoundary != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeRunnerExecutionBoundaryCard(
            observation: runnerExecutionBoundary,
          ),
        ),
      if (runnerAttemptBoundary != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeRunnerAttemptBoundaryCard(
            observation: runnerAttemptBoundary,
          ),
        ),
      if (localRunnerPreview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeLocalRunnerPreviewCard(observation: localRunnerPreview),
        ),
      if (executionConsentPreview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeExecutionConsentPreviewCard(
            preview: executionConsentPreview,
          ),
        ),
    ];
  }
}
