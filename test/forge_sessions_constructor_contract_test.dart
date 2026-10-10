import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

List<bool> _switches(ForgeSessionsGate gate) => [
  gate.enableConversationChangesStream,
  gate.enableRunnerExecutionIntentCandidate,
  gate.enableLocalRunnerPreviewCandidate,
  gate.enableRunObservedCandidate,
  gate.enableDeviceInventoryV2Candidate,
  gate.enableSessionRunnerReconciliationProjectionCandidate,
  gate.enableSessionRunnerReconciliationProjectionHistoryChainCandidate,
  gate.enableSessionRunnerReceiptHistoryCandidate,
  gate.enableRunExecutionEvidenceCandidate,
  gate.enableExecutionReconciliationCandidate,
  gate.enableExecutionConsentPreviewCandidate,
  gate.enableRunnerAttemptBoundaryCandidate,
  gate.enableRunnerAttemptBoundaryProjection,
  gate.enablePendingRunIntentCandidate,
  gate.enablePromptAppendReceiptCandidate,
  gate.requireDeviceInventoryResourceConvergenceForPromptAppend,
  gate.enableDeviceInventoryCandidate,
  gate.enableDeviceInventoryResourceConvergenceCandidate,
  gate.enableDeviceInventoryRegistryPlacementPreviewCandidate,
  gate.enableSchedulerSelectionPreviewCandidate,
  gate.enableSchedulerSelectionLeaseCandidate,
  gate.enableSchedulerSelectionLeaseRenewalCandidate,
  gate.enableSchedulerSelectionLeaseReleaseCandidate,
  gate.enableClientInstanceResourceViewCandidate,
  gate.enableRunAttemptLeaseDispatchPreflightCandidate,
  gate.enableRunnerDispatchPlanPreviewCandidate,
  gate.enableRunnerDispatchAdmissionCandidate,
  gate.enableRunnerTransportAdmissionCandidate,
  gate.enableRunnerExecutionBoundaryCandidate,
  gate.enableClientInstanceSessionViewCandidate,
  gate.enableClientInstanceSessionResourceConvergenceCandidate,
  gate.enableLifecycleRegistryCandidate,
  gate.enableDeviceCredentialCandidate,
];

List<String?> _origins(ForgeSessionsGate gate) => [
  gate.runnerExecutionIntentCandidateApiOrigin,
  gate.localRunnerPreviewCandidateApiOrigin,
  gate.runObservedCandidateApiOrigin,
  gate.deviceInventoryV2CandidateApiOrigin,
  gate.sessionRunnerReconciliationProjectionCandidateApiOrigin,
  gate.sessionRunnerReceiptHistoryCandidateApiOrigin,
  gate.runExecutionEvidenceCandidateApiOrigin,
  gate.executionReconciliationCandidateApiOrigin,
  gate.executionConsentPreviewCandidateApiOrigin,
  gate.runnerAttemptBoundaryCandidateApiOrigin,
  gate.pendingRunIntentCandidateApiOrigin,
  gate.promptAppendReceiptCandidateApiOrigin,
  gate.deviceInventoryCandidateApiOrigin,
  gate.deviceInventoryResourceConvergenceCandidateApiOrigin,
  gate.deviceInventoryRegistryPlacementPreviewCandidateApiOrigin,
  gate.schedulerSelectionPreviewCandidateApiOrigin,
  gate.schedulerSelectionLeaseCandidateApiOrigin,
  gate.schedulerSelectionLeaseRenewalCandidateApiOrigin,
  gate.schedulerSelectionLeaseReleaseCandidateApiOrigin,
  gate.clientInstanceResourceViewCandidateApiOrigin,
  gate.runAttemptLeaseDispatchPreflightCandidateApiOrigin,
  gate.runnerDispatchPlanPreviewCandidateApiOrigin,
  gate.runnerDispatchAdmissionCandidateApiOrigin,
  gate.runnerTransportAdmissionCandidateApiOrigin,
  gate.runnerExecutionBoundaryCandidateApiOrigin,
  gate.clientInstanceSessionViewCandidateApiOrigin,
  gate.clientInstanceSessionResourceConvergenceCandidateApiOrigin,
  gate.lifecycleRegistryCandidateApiOrigin,
  gate.deviceCredentialCandidateApiOrigin,
];

void main() {
  test('const Gate keeps every explicit candidate off and origins unset', () {
    const gate = ForgeSessionsGate();
    expect(_switches(gate), everyElement(isFalse));
    expect(_origins(gate), everyElement(isNull));
    expect(gate.conversationChangesStreamWaitMS, 15000);
    expect(gate.credentialStore, isNull);
    expect(gate.initialConversationID, isNull);
    expect(gate.initialClientInstanceID, isNull);
    expect(gate.httpClient, isNull);
    expect(gate.testScreenBuilder, isNull);
    expect(gate.testScreenBuilderWithRoute, isNull);
  });

  test('const Gate preserves all explicit switches and distinct origins', () {
    // Merely constructing these options never mounts or enables an API.
    const gate = ForgeSessionsGate(
      enableConversationChangesStream: true,
      enableRunnerExecutionIntentCandidate: true,
      enableLocalRunnerPreviewCandidate: true,
      enableRunObservedCandidate: true,
      enableDeviceInventoryV2Candidate: true,
      enableSessionRunnerReconciliationProjectionCandidate: true,
      enableSessionRunnerReconciliationProjectionHistoryChainCandidate: true,
      enableSessionRunnerReceiptHistoryCandidate: true,
      enableRunExecutionEvidenceCandidate: true,
      enableExecutionReconciliationCandidate: true,
      enableExecutionConsentPreviewCandidate: true,
      enableRunnerAttemptBoundaryCandidate: true,
      enableRunnerAttemptBoundaryProjection: true,
      enablePendingRunIntentCandidate: true,
      enablePromptAppendReceiptCandidate: true,
      requireDeviceInventoryResourceConvergenceForPromptAppend: true,
      enableDeviceInventoryCandidate: true,
      enableDeviceInventoryResourceConvergenceCandidate: true,
      enableDeviceInventoryRegistryPlacementPreviewCandidate: true,
      enableSchedulerSelectionPreviewCandidate: true,
      enableSchedulerSelectionLeaseCandidate: true,
      enableSchedulerSelectionLeaseRenewalCandidate: true,
      enableSchedulerSelectionLeaseReleaseCandidate: true,
      enableClientInstanceResourceViewCandidate: true,
      enableRunAttemptLeaseDispatchPreflightCandidate: true,
      enableRunnerDispatchPlanPreviewCandidate: true,
      enableRunnerDispatchAdmissionCandidate: true,
      enableRunnerTransportAdmissionCandidate: true,
      enableRunnerExecutionBoundaryCandidate: true,
      enableClientInstanceSessionViewCandidate: true,
      enableClientInstanceSessionResourceConvergenceCandidate: true,
      enableLifecycleRegistryCandidate: true,
      enableDeviceCredentialCandidate: true,
      runnerExecutionIntentCandidateApiOrigin: 'https://candidate-0.invalid',
      localRunnerPreviewCandidateApiOrigin: 'https://candidate-1.invalid',
      runObservedCandidateApiOrigin: 'https://candidate-2.invalid',
      deviceInventoryV2CandidateApiOrigin: 'https://candidate-3.invalid',
      sessionRunnerReconciliationProjectionCandidateApiOrigin:
          'https://candidate-4.invalid',
      sessionRunnerReceiptHistoryCandidateApiOrigin:
          'https://candidate-5.invalid',
      runExecutionEvidenceCandidateApiOrigin: 'https://candidate-6.invalid',
      executionReconciliationCandidateApiOrigin: 'https://candidate-7.invalid',
      executionConsentPreviewCandidateApiOrigin: 'https://candidate-8.invalid',
      runnerAttemptBoundaryCandidateApiOrigin: 'https://candidate-9.invalid',
      pendingRunIntentCandidateApiOrigin: 'https://candidate-10.invalid',
      promptAppendReceiptCandidateApiOrigin: 'https://candidate-11.invalid',
      deviceInventoryCandidateApiOrigin: 'https://candidate-12.invalid',
      deviceInventoryResourceConvergenceCandidateApiOrigin:
          'https://candidate-13.invalid',
      deviceInventoryRegistryPlacementPreviewCandidateApiOrigin:
          'https://candidate-14.invalid',
      schedulerSelectionPreviewCandidateApiOrigin:
          'https://candidate-15.invalid',
      schedulerSelectionLeaseCandidateApiOrigin: 'https://candidate-16.invalid',
      schedulerSelectionLeaseRenewalCandidateApiOrigin:
          'https://candidate-17.invalid',
      schedulerSelectionLeaseReleaseCandidateApiOrigin:
          'https://candidate-18.invalid',
      clientInstanceResourceViewCandidateApiOrigin:
          'https://candidate-19.invalid',
      runAttemptLeaseDispatchPreflightCandidateApiOrigin:
          'https://candidate-20.invalid',
      runnerDispatchPlanPreviewCandidateApiOrigin:
          'https://candidate-21.invalid',
      runnerDispatchAdmissionCandidateApiOrigin: 'https://candidate-22.invalid',
      runnerTransportAdmissionCandidateApiOrigin:
          'https://candidate-23.invalid',
      runnerExecutionBoundaryCandidateApiOrigin: 'https://candidate-24.invalid',
      clientInstanceSessionViewCandidateApiOrigin:
          'https://candidate-25.invalid',
      clientInstanceSessionResourceConvergenceCandidateApiOrigin:
          'https://candidate-26.invalid',
      lifecycleRegistryCandidateApiOrigin: 'https://candidate-27.invalid',
      deviceCredentialCandidateApiOrigin: 'https://candidate-28.invalid',
    );
    expect(_switches(gate), everyElement(isTrue));
    expect(_origins(gate), [
      for (var i = 0; i < 29; i++) 'https://candidate-$i.invalid',
    ]);
  });

  test('const Screen keeps transport defaults and opt-in seams unchanged', () {
    const screen = ForgeSessionsScreen(
      accessToken: 'fixture-only',
      apiOrigin: 'https://forge.invalid',
    );
    expect(screen.accessToken, 'fixture-only');
    expect(screen.apiOrigin, 'https://forge.invalid');
    expect(screen.enableConversationChangesStream, isFalse);
    expect(screen.conversationChangesStreamWaitMS, 15000);
    expect(screen.oauthRevocationTimeout, const Duration(seconds: 5));
    expect(screen.enableRunnerAttemptBoundaryProjection, isFalse);
    expect(
      screen.requireDeviceInventoryResourceConvergenceForPromptAppend,
      isFalse,
    );
    expect(screen.credentialStore, isNull);
    expect(screen.httpClient, isNull);
    expect(screen.oauthHttpClient, isNull);
    expect(screen.initialConversationID, isNull);
    expect(screen.initialClientInstanceID, isNull);
    expect(screen.schedulerSelectionLeaseReader, isNull);
    expect(screen.schedulerSelectionLeaseRenewalReader, isNull);
    expect(screen.schedulerSelectionLeaseReleaseReader, isNull);
    expect(screen.promptAppendReceiptSubmitter, isNull);
    expect(screen.pendingRunIntentSubmitter, isNull);
  });

  test('inherited transport values retain clients, store, route and Key', () {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      throw StateError('Constructing options must not perform HTTP');
    });
    final oauth = MockClient((_) async {
      calls++;
      throw StateError('Constructing options must not perform OAuth');
    });
    addTearDown(client.close);
    addTearDown(oauth.close);
    final store = ForgeCredentialStore();
    const key = ValueKey('fixture-route');
    final screen = ForgeSessionsScreen(
      key: key,
      accessToken: 'fixture-only',
      apiOrigin: 'https://forge.invalid',
      httpClient: client,
      oauthHttpClient: oauth,
      credentialStore: store,
      enableConversationChangesStream: true,
      conversationChangesStreamWaitMS: 0,
      oauthRevocationTimeout: const Duration(seconds: 2),
      initialConversationID: 'conversation/opaque',
      initialClientInstanceID: 'instance/opaque',
    );
    final gate = ForgeSessionsGate(
      key: key,
      credentialStore: store,
      httpClient: client,
      conversationChangesStreamWaitMS: 42,
      initialConversationID: 'conversation/opaque',
      initialClientInstanceID: 'instance/opaque',
    );
    expect(screen.key, same(key));
    expect(gate.key, same(key));
    expect(screen.httpClient, same(client));
    expect(screen.oauthHttpClient, same(oauth));
    expect(screen.credentialStore, same(store));
    expect(gate.httpClient, same(client));
    expect(gate.credentialStore, same(store));
    expect(screen.initialConversationID, gate.initialConversationID);
    expect(screen.initialClientInstanceID, gate.initialClientInstanceID);
    expect(screen.conversationChangesStreamWaitMS, 0);
    expect(gate.conversationChangesStreamWaitMS, 42);
    expect(screen.oauthRevocationTimeout, const Duration(seconds: 2));
    expect(calls, 0);
  });
}
