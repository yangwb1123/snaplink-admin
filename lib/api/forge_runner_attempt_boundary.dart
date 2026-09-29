import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';
import 'forge_runner_execution_intent.dart';
import 'forge_runner_execution_boundary.dart';

part 'forge_runner_attempt_boundary_validation.dart';

/// The strict, display-only Flutter projection of the Runner Attempt
/// lifecycle boundary. It carries no command payload or Runner response.
const forgeRunnerAttemptBoundarySchema = 'forge.runner-attempt-boundary/v1';
const forgeRunnerAttemptBoundaryEvaluationMode =
    'attempt_lifecycle_dispatch_boundary_preview';
const forgeRunnerAttemptBoundaryMaxSafeInteger = 9007199254740991;
const forgeRunnerAttemptBoundaryMaxInputBytes = 2 * 1024 * 1024;

/// Supplies one bounded local Attempt boundary document. The callback has no
/// network, lease, persistence, Runner, or Audit authority.
typedef ForgeRunnerAttemptBoundaryFileReader = Future<String?> Function();

/// The flattened request accepted by the authenticated Core preview route.
/// The nested execution-boundary request remains caller supplied and carries
/// no Runner payload, credential, or lease mutation authority.
class ForgeRunnerAttemptBoundaryPreviewRequest {
  final ForgeRunnerExecutionBoundaryPreviewRequest executionBoundary;
  final String transition;

  const ForgeRunnerAttemptBoundaryPreviewRequest({
    required this.executionBoundary,
    required this.transition,
  });

  ForgeDeviceOwner get owner => executionBoundary.owner;
  String get conversationID => executionBoundary.conversationID;
  String get runID => executionBoundary.runID;
  String get attemptID => executionBoundary.attemptID;
  String get attemptState => executionBoundary.attemptState;
  ForgeRunnerExecutionCommand get command => executionBoundary.command;

  factory ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(Object? value) {
    final json = _attemptBoundaryObject(
      value,
      'Runner Attempt boundary request',
    );
    _attemptBoundaryExactKeys(json, {
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'attempt_state',
      'command',
      'transport',
      'expected_payload_sha256',
      'controls',
      'transition',
    }, 'Runner Attempt boundary request');
    final transition = _attemptBoundaryTransition(json['transition']);
    final executionJSON = Map<String, dynamic>.from(json)..remove('transition');
    return ForgeRunnerAttemptBoundaryPreviewRequest(
      executionBoundary: ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(
        executionJSON,
      ),
      transition: transition,
    );
  }

  Map<String, dynamic> toJson() => {
    ...executionBoundary.toJson(),
    'transition': transition,
  };
}

/// Reads one explicit authenticated, owner/Run/Attempt-bound Attempt
/// lifecycle preview. The callback is unset in the default Gate.
typedef ForgeRunnerAttemptBoundaryReader =
    Future<ForgeRunnerAttemptBoundaryObservation> Function(
      ForgeRunnerAttemptBoundaryPreviewRequest request,
    );

class ForgeRunnerAttemptBoundaryAuthority {
  final bool attemptPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeRunnerAttemptBoundaryAuthority({
    required this.attemptPersisted,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeRunnerAttemptBoundaryAuthority.fromJson(Object? value) {
    final json = _attemptBoundaryObject(value, 'authority');
    _attemptBoundaryExactKeys(json, {
      'attempt_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    }, 'authority');
    final authority = ForgeRunnerAttemptBoundaryAuthority(
      attemptPersisted: _attemptBoundaryBool(json, 'attempt_persisted'),
      reservationCreated: _attemptBoundaryBool(json, 'reservation_created'),
      executionAuthorized: _attemptBoundaryBool(json, 'execution_authorized'),
      dispatchPerformed: _attemptBoundaryBool(json, 'dispatch_performed'),
      auditPublished: _attemptBoundaryBool(json, 'audit_published'),
    );
    if (!authority.isClear) {
      throw const FormatException(
        'Runner Attempt boundary observation claims authority.',
      );
    }
    return authority;
  }

  bool get isClear =>
      !attemptPersisted &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  Map<String, dynamic> toJson() => {
    'attempt_persisted': attemptPersisted,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

/// Expected owner and selected session scope for one local boundary
/// projection. The scope is supplied by the caller; it is never inferred from
/// a bearer token or from the imported observation.
class ForgeRunnerAttemptBoundaryScope {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;

  const ForgeRunnerAttemptBoundaryScope({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
  });

  bool matches(ForgeRunnerAttemptBoundaryObservation observation) =>
      owner == observation.owner &&
      conversationID == observation.conversationID &&
      runID == observation.runID &&
      attemptID == observation.attemptID;

  bool matchesSelected(String? selectedConversationID, String? selectedRunID) =>
      conversationID == selectedConversationID && runID == selectedRunID;
}

/// A validated lifecycle observation. A ready value remains preview-only and
/// does not authorize a transition, lease, command, or device.
class ForgeRunnerAttemptBoundaryObservation {
  static const schema = forgeRunnerAttemptBoundarySchema;
  static const evaluationMode = forgeRunnerAttemptBoundaryEvaluationMode;
  static const maxSafeInteger = forgeRunnerAttemptBoundaryMaxSafeInteger;

  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String commandID;
  final String targetID;
  final int leaseEpoch;
  final String currentAttemptState;
  final String nextAttemptState;
  final String transition;
  final bool executionBoundaryReady;
  final bool attemptTransitionValid;
  final bool attemptTransitionDispatchable;
  final bool attemptBoundaryReady;
  final List<String> rejectionReasons;
  final ForgeRunnerAttemptBoundaryAuthority authority;

  const ForgeRunnerAttemptBoundaryObservation({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.commandID,
    required this.targetID,
    required this.leaseEpoch,
    required this.currentAttemptState,
    required this.nextAttemptState,
    required this.transition,
    required this.executionBoundaryReady,
    required this.attemptTransitionValid,
    required this.attemptTransitionDispatchable,
    required this.attemptBoundaryReady,
    required this.rejectionReasons,
    required this.authority,
  });

  factory ForgeRunnerAttemptBoundaryObservation.fromJsonText(String source) {
    if (source.isEmpty ||
        source.length > forgeRunnerAttemptBoundaryMaxInputBytes) {
      throw const FormatException(
        'Runner Attempt boundary input exceeds the size limit.',
      );
    }
    rejectDuplicateForgeJsonKeys(source);
    return ForgeRunnerAttemptBoundaryObservation.fromJson(jsonDecode(source));
  }

  factory ForgeRunnerAttemptBoundaryObservation.fromJson(Object? value) {
    final json = _attemptBoundaryObject(value, 'Runner Attempt boundary');
    _attemptBoundaryExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'command_id',
      'target_id',
      'lease_epoch',
      'current_attempt_state',
      'next_attempt_state',
      'transition',
      'execution_boundary_ready',
      'attempt_transition_valid',
      'attempt_transition_dispatchable',
      'attempt_boundary_ready',
      'rejection_reasons',
      'preview_only',
      'authority',
    }, 'Runner Attempt boundary');
    if (json['schema_version'] != schema ||
        json['evaluation_mode'] != evaluationMode ||
        json['preview_only'] != true) {
      throw const FormatException('Invalid Runner Attempt boundary envelope.');
    }
    final current = _attemptBoundaryState(json['current_attempt_state']);
    final next = _attemptBoundaryState(json['next_attempt_state']);
    final transition = _attemptBoundaryTransition(json['transition']);
    final executionReady = _attemptBoundaryBool(
      json,
      'execution_boundary_ready',
    );
    final transitionValid = _attemptBoundaryBool(
      json,
      'attempt_transition_valid',
    );
    final transitionDispatchable = _attemptBoundaryBool(
      json,
      'attempt_transition_dispatchable',
    );
    final boundaryReady = _attemptBoundaryBool(json, 'attempt_boundary_ready');
    final reasons = _attemptBoundaryReasons(json['rejection_reasons']);
    final expectedValid = _attemptBoundaryValidTransition(current, next);
    final expectedDispatchable = _attemptBoundaryDispatchable(current, next);
    final expectedReasons = _attemptBoundaryRejectionReasons(
      executionReady,
      expectedValid,
      expectedDispatchable,
    );
    if (next != _attemptBoundaryTransitionTarget(transition) ||
        transitionValid != expectedValid ||
        transitionDispatchable != expectedDispatchable ||
        (executionReady && !_attemptBoundaryDispatchableState(current)) ||
        boundaryReady != (executionReady && expectedDispatchable) ||
        !_attemptBoundarySameStrings(reasons, expectedReasons) ||
        (boundaryReady && reasons.isNotEmpty)) {
      throw const FormatException(
        'Invalid Runner Attempt boundary lifecycle binding.',
      );
    }
    return ForgeRunnerAttemptBoundaryObservation(
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _attemptBoundaryIdentifier(json['conversation_id']),
      runID: _attemptBoundaryIdentifier(json['run_id']),
      attemptID: _attemptBoundaryIdentifier(json['attempt_id']),
      commandID: _attemptBoundaryIdentifier(json['command_id']),
      targetID: _attemptBoundaryIdentifier(json['target_id']),
      leaseEpoch: _attemptBoundaryPositiveInt(json, 'lease_epoch'),
      currentAttemptState: current,
      nextAttemptState: next,
      transition: transition,
      executionBoundaryReady: executionReady,
      attemptTransitionValid: transitionValid,
      attemptTransitionDispatchable: transitionDispatchable,
      attemptBoundaryReady: boundaryReady,
      rejectionReasons: List.unmodifiable(reasons),
      authority: ForgeRunnerAttemptBoundaryAuthority.fromJson(
        json['authority'],
      ),
    );
  }

  bool get isDisplayOnly => authority.isClear;

  bool isFor(String conversationID, String runID, String attemptID) =>
      this.conversationID == conversationID &&
      this.runID == runID &&
      this.attemptID == attemptID;

  Map<String, dynamic> toJson() => {
    'schema_version': schema,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'command_id': commandID,
    'target_id': targetID,
    'lease_epoch': leaseEpoch,
    'current_attempt_state': currentAttemptState,
    'next_attempt_state': nextAttemptState,
    'transition': transition,
    'execution_boundary_ready': executionBoundaryReady,
    'attempt_transition_valid': attemptTransitionValid,
    'attempt_transition_dispatchable': attemptTransitionDispatchable,
    'attempt_boundary_ready': attemptBoundaryReady,
    'rejection_reasons': rejectionReasons,
    'preview_only': true,
    'authority': authority.toJson(),
  };
}
