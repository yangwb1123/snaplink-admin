part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayRunnerValidation on _ForgeSessionsScreenState {
  ForgeSchedulerSelectionPreview? _strictSchedulerSelectionPreview(
    ForgeSchedulerSelectionPreview? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeSchedulerSelectionPreview.fromJson(
        candidate.toJson(),
      );
      return validated.authority.anyGranted || !validated.previewOnly
          ? null
          : validated;
    } on FormatException {
      return null;
    }
  }

  ForgeSchedulerSelectionPreview? _schedulerSelectionPreviewFor(
    ForgeSchedulerSelectionPreview? staticPreview,
    ForgeSchedulerSelectionPreview? fetchedPreview,
    String? conversationID,
    String? runID,
  ) {
    for (final candidate in [staticPreview, fetchedPreview]) {
      if (candidate != null &&
          conversationID != null &&
          runID != null &&
          candidate.isFor(conversationID, runID) &&
          _schedulerSelectionTargetMatchesResources(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  ForgeSchedulerSelectionLease? _strictSchedulerSelectionLease(
    ForgeSchedulerSelectionLease? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeSchedulerSelectionLease.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeSchedulerSelectionLeaseRelease? _strictSchedulerSelectionLeaseRelease(
    ForgeSchedulerSelectionLeaseRelease? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeSchedulerSelectionLeaseRelease.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeSchedulerSelectionLeaseRelease? _schedulerSelectionLeaseReleaseFor(
    ForgeSchedulerSelectionLeaseRelease? staticRelease,
    ForgeSchedulerSelectionLeaseRelease? fetchedRelease,
    String? conversationID,
    String? runID,
    String? attemptID,
  ) {
    for (final candidate in [staticRelease, fetchedRelease]) {
      if (candidate != null &&
          conversationID != null &&
          runID != null &&
          candidate.isFor(
            conversationID,
            runID,
            attemptID ?? candidate.attemptID,
          ) &&
          (attemptID == null || candidate.attemptID == attemptID)) {
        return candidate;
      }
    }
    return null;
  }

  ForgeSchedulerSelectionLease? _schedulerSelectionLeaseFor(
    ForgeSchedulerSelectionLease? staticLease,
    ForgeSchedulerSelectionLease? fetchedLease,
    String? conversationID,
    String? runID,
    String? attemptID,
  ) {
    for (final candidate in [staticLease, fetchedLease]) {
      if (candidate != null &&
          conversationID != null &&
          runID != null &&
          candidate.isFor(
            conversationID,
            runID,
            attemptID ?? candidate.attemptID,
          ) &&
          (attemptID == null || candidate.attemptID == attemptID)) {
        return candidate;
      }
    }
    return null;
  }

  ForgePreflightFixture? _strictRunAttemptLeaseDispatchPreflight(
    ForgePreflightFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgePreflightFixture.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerDispatchPlanPreview? _strictRunnerDispatchPlanPreview(
    ForgeRunnerDispatchPlanPreview? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerDispatchPlanPreview.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerDispatchAdmission? _strictRunnerDispatchAdmission(
    ForgeRunnerDispatchAdmission? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerDispatchAdmission.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerTransportAdmission? _strictRunnerTransportAdmission(
    ForgeRunnerTransportAdmission? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerTransportAdmission.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerExecutionBoundaryObservation? _strictRunnerExecutionBoundary(
    ForgeRunnerExecutionBoundaryObservation? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerExecutionBoundaryObservation.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerAttemptBoundaryObservation? _strictRunnerAttemptBoundary(
    ForgeRunnerAttemptBoundaryObservation? candidate,
    String? selectedConversationID,
    String? selectedRunID,
  ) {
    final scope = widget.runnerAttemptBoundaryScope;
    if (!widget.enableRunnerAttemptBoundaryProjection ||
        candidate == null ||
        scope == null ||
        !scope.matchesSelected(selectedConversationID, selectedRunID)) {
      return null;
    }
    try {
      final validated = ForgeRunnerAttemptBoundaryObservation.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly && scope.matches(validated)
          ? validated
          : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerAttemptBoundaryObservation? _strictFetchedRunnerAttemptBoundary(
    ForgeRunnerAttemptBoundaryObservation? candidate,
    String? selectedConversationID,
    String? selectedRunID,
  ) {
    final request = widget.runnerAttemptBoundaryRequest;
    if (candidate == null ||
        request == null ||
        selectedConversationID == null ||
        selectedRunID == null ||
        request.conversationID != selectedConversationID ||
        request.runID != selectedRunID) {
      return null;
    }
    try {
      final validated = ForgeRunnerAttemptBoundaryObservation.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly &&
              validated.owner == request.owner &&
              validated.isFor(
                selectedConversationID,
                selectedRunID,
                request.attemptID,
              ) &&
              validated.currentAttemptState == request.attemptState &&
              validated.transition == request.transition
          ? validated
          : null;
    } on FormatException {
      return null;
    }
  }
}
