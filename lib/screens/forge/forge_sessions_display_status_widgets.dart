part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayStatusWidgets on _ForgeSessionsScreenState {
  Widget _errorCard(
    BuildContext context,
    String message,
    VoidCallback onSignIn,
  ) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: Text(context.tr(message))),
          if (message == _forgeAuthRequiredMessage)
            TextButton(onPressed: onSignIn, child: Text(context.tr('Sign in'))),
        ],
      ),
    ),
  );

  Widget _staleConversationsCard(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge is offline or unavailable. Showing cached session metadata; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleDeviceInventoryCard(BuildContext context) => Card(
    key: const ValueKey('forge-device-inventory-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge device inventory is refreshing or unavailable. Showing the last verified snapshot; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleDeviceInventoryV2Card(BuildContext context) => Card(
    key: const ValueKey('forge-device-inventory-v2-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge v2 device inventory is refreshing or unavailable. Showing the last verified snapshot; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleDeviceInventoryResourceConvergenceCard(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-device-inventory-resource-convergence-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge converged device resources are refreshing or unavailable. Showing the last validated pair; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRegistryPlacementPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-device-registry-placement-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      leading: Icon(Icons.cloud_off_outlined),
      title: LocalizedText(
        'Forge registry placement preview is refreshing or unavailable. Showing the last validated comparison; it may be stale.',
      ),
    ),
  );

  Widget _staleSchedulerSelectionPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      leading: Icon(Icons.cloud_off_outlined),
      title: LocalizedText(
        'Forge scheduler selection is refreshing or unavailable. Showing the last validated preview; it may be stale.',
      ),
    ),
  );

  Widget _staleSchedulerSelectionLeaseCard(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-lease-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      leading: Icon(Icons.cloud_off_outlined),
      title: LocalizedText(
        'Forge scheduler lease is unavailable. The displayed lease was not renewed.',
      ),
    ),
  );

  Widget _staleSchedulerSelectionLeaseReleaseCard(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-lease-release-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      leading: Icon(Icons.cloud_off_outlined),
      title: LocalizedText(
        'Forge scheduler lease release is unavailable. The displayed release receipt may be stale.',
      ),
    ),
  );

  Widget _staleClientInstanceResourceViewCard(BuildContext context) => Card(
    key: const ValueKey('forge-client-instance-resource-view-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge client-instance resources are refreshing or unavailable. Showing the last validated view; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleClientInstanceSessionViewCard(BuildContext context) => Card(
    key: const ValueKey('forge-client-instance-session-view-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge client-instance sessions are refreshing or unavailable. Showing the last validated view; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleClientInstanceSessionResourceConvergenceCard(
    BuildContext context,
  ) => Card(
    key: const ValueKey(
      'forge-client-instance-session-resource-convergence-stale',
    ),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge client-instance session and resource observations are refreshing or unavailable. Showing the last validated pair; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleLifecycleRegistryCard(BuildContext context) => Card(
    key: const ValueKey('forge-lifecycle-registry-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge lifecycle registry is refreshing or unavailable. Showing the last validated snapshot; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleDeviceCredentialCandidateCard(BuildContext context) => Card(
    key: const ValueKey('forge-device-credential-candidate-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge credential lifecycle candidate is unavailable. No credential material was retained.',
        ),
      ),
    ),
  );

  Widget _staleRunObservedCard(BuildContext context) => Card(
    key: const ValueKey('forge-run-observed-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Run metadata is refreshing or unavailable. Showing the last validated observation; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunAttemptLeaseDispatchPreflightCard(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-run-attempt-lease-dispatch-preflight-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Run-Attempt lease preflight is refreshing or unavailable. Showing the last validated preview; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerDispatchPlanPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-dispatch-plan-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner dispatch-plan preview is refreshing or unavailable. Showing the last validated comparison; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerDispatchAdmissionCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-dispatch-admission-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner dispatch admission is refreshing or unavailable. Showing the last validated recheck; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerTransportAdmissionCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-transport-admission-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner transport admission is refreshing or unavailable. Showing the last validated preview; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerExecutionBoundaryCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-execution-boundary-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner execution boundary is refreshing or unavailable. Showing the last validated preview; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerAttemptBoundaryCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-attempt-boundary-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner Attempt boundary is refreshing or unavailable. Showing the last validated preview; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleLocalRunnerPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-local-runner-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Local Runner execution-readiness preview is refreshing or unavailable. Showing the last validated observation; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleExecutionConsentPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-execution-consent-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge execution consent preview is refreshing or unavailable. Showing the last validated metadata; it may be stale.',
        ),
      ),
    ),
  );

  Widget _inlineError(
    BuildContext context,
    String message,
    VoidCallback onSignIn,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.tr(message),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        if (message == _forgeAuthRequiredMessage)
          TextButton(onPressed: onSignIn, child: Text(context.tr('Sign in'))),
      ],
    ),
  );
}
