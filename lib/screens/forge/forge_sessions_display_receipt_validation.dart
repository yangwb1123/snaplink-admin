part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayReceiptValidation on _ForgeSessionsScreenState {
  ForgeRunExecutionEvidence? _strictRunExecutionEvidence(
    ForgeRunExecutionEvidence? candidate,
  ) {
    if (candidate == null) return null;
    try {
      // Re-decode the caller-supplied wire projection so a manually
      // constructed value cannot bypass the strict fixture contract.
      return ForgeRunExecutionEvidence.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeExecutionReconciliationObservation?
  _strictExecutionReconciliationObservation(
    ForgeExecutionReconciliationObservation? candidate,
  ) {
    if (candidate == null) return null;
    try {
      // Re-decode the caller-supplied wire projection so a manually
      // constructed value cannot bypass the strict observation contract.
      return ForgeExecutionReconciliationObservation.fromJson(
        candidate.toJson(),
      );
    } on FormatException {
      return null;
    }
  }

  ForgeExecutionConsentPreview? _strictExecutionConsentPreview(
    ForgeExecutionConsentPreview? candidate,
    String? selectedConversationID,
  ) {
    if (candidate == null || selectedConversationID == null) return null;
    try {
      final validated = ForgeExecutionConsentPreview.fromJson(
        candidate.toJson(),
      );
      return validated.conversationID == selectedConversationID
          ? validated
          : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunObserved? _strictRunObserved(ForgeRunObserved? candidate) {
    if (candidate == null) return null;
    try {
      // Re-decode the caller-supplied wire projection so a manually
      // constructed value cannot bypass the strict observer contract.
      return ForgeRunObserved.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeClientInstanceSessionView? _strictClientInstanceSessionView(
    ForgeClientInstanceSessionView? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeClientInstanceSessionView.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeClientInstanceResourceView? _strictClientInstanceResourceView(
    ForgeClientInstanceResourceView? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeClientInstanceResourceView.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryResourceConvergence?
  _strictDeviceInventoryResourceConvergence(
    ForgeDeviceInventoryResourceConvergence? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceInventoryResourceConvergence.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeExecutionLeaseCheckpointFixture? _strictExecutionLeaseCheckpoint(
    ForgeExecutionLeaseCheckpointFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeExecutionLeaseCheckpointFixture.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceEnrollmentHeartbeatLifecycleRegistry? _strictLifecycleRegistry(
    ForgeDeviceEnrollmentHeartbeatLifecycleRegistry? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        candidate.toJson(),
      );
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceCredentialLifecycleCandidate? _strictDeviceCredentialCandidate(
    ForgeDeviceCredentialLifecycleCandidate? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeDeviceCredentialLifecycleCandidate.fromJson(
        candidate.toJson(),
      );
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceRegistryPlacementPreview? _strictRegistryPlacementPreview(
    ForgeDeviceRegistryPlacementPreview? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeDeviceRegistryPlacementPreview.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }
}
