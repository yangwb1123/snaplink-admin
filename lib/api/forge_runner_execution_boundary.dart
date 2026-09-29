import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';
import 'forge_runner_execution_intent.dart';
import 'forge_runner_transport_admission.dart';

part 'forge_runner_execution_boundary_validation.dart';

/// Caller-supplied values for the authenticated, metadata-only Runner
/// execution-boundary preview. Activation, Runner authority, lease state, and
/// evaluation time are server-owned and are intentionally absent here.
class ForgeRunnerExecutionBoundaryPreviewRequest {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String attemptState;
  final ForgeRunnerExecutionCommand command;
  final ForgeRunnerTransportObservation transport;
  final String expectedPayloadSHA256;
  final String effectState;
  final bool cancellationRequested;

  const ForgeRunnerExecutionBoundaryPreviewRequest({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.attemptState,
    required this.command,
    required this.transport,
    required this.expectedPayloadSHA256,
    required this.effectState,
    required this.cancellationRequested,
  });

  factory ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(Object? value) {
    final json = _boundaryObject(value, 'Runner execution boundary request');
    _boundaryExactKeys(json, {
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'attempt_state',
      'command',
      'transport',
      'expected_payload_sha256',
      'controls',
    }, 'Runner execution boundary request');
    final attemptID = _boundaryIdentifier(json['attempt_id']);
    final command = _boundaryCommand(json['command']);
    if (command.leaseProof.attemptID != attemptID) {
      throw const FormatException(
        'Runner execution boundary proof is not bound to the Attempt.',
      );
    }
    final controls = _boundaryObject(json['controls'], 'controls');
    _boundaryExactKeys(controls, {
      'effect_state',
      'cancellation_requested',
    }, 'controls');
    return ForgeRunnerExecutionBoundaryPreviewRequest(
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _boundaryIdentifier(json['conversation_id']),
      runID: _boundaryIdentifier(json['run_id']),
      attemptID: attemptID,
      attemptState: _boundaryState(json['attempt_state']),
      command: command,
      transport: ForgeRunnerTransportObservation.fromJson(json['transport']),
      expectedPayloadSHA256: _boundaryDigest(json['expected_payload_sha256']),
      effectState: _boundaryEffectState(controls['effect_state']),
      cancellationRequested: _boundaryBool(controls, 'cancellation_requested'),
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'attempt_state': attemptState,
    'command': _boundaryCommandToJson(command),
    'transport': transport.toJson(),
    'expected_payload_sha256': expectedPayloadSHA256,
    'controls': {
      'effect_state': effectState,
      'cancellation_requested': cancellationRequested,
    },
  };
}

class ForgeRunnerExecutionBoundaryAuthority {
  final bool deviceIdentityVerified;
  final bool commandPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeRunnerExecutionBoundaryAuthority({
    required this.deviceIdentityVerified,
    required this.commandPersisted,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeRunnerExecutionBoundaryAuthority.fromJson(Object? value) {
    final json = _boundaryObject(value, 'authority');
    _boundaryExactKeys(json, {
      'device_identity_verified',
      'command_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    }, 'authority');
    final authority = ForgeRunnerExecutionBoundaryAuthority(
      deviceIdentityVerified: _boundaryBool(json, 'device_identity_verified'),
      commandPersisted: _boundaryBool(json, 'command_persisted'),
      reservationCreated: _boundaryBool(json, 'reservation_created'),
      executionAuthorized: _boundaryBool(json, 'execution_authorized'),
      dispatchPerformed: _boundaryBool(json, 'dispatch_performed'),
      auditPublished: _boundaryBool(json, 'audit_published'),
    );
    if (!authority.isClear) {
      throw const FormatException(
        'Runner execution boundary response claims authority.',
      );
    }
    return authority;
  }

  bool get isClear =>
      !deviceIdentityVerified &&
      !commandPersisted &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  Map<String, dynamic> toJson() => {
    'device_identity_verified': deviceIdentityVerified,
    'command_persisted': commandPersisted,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

/// Server-owned result for one execution-boundary preview. It is always
/// display-only, including when all gates report ready.
class ForgeRunnerExecutionBoundaryObservation {
  static const schema = 'forge.runner-execution-boundary/v1';
  static const evaluationMode =
      'p4_runner_authority_execution_boundary_preview';
  static const maxSafeInteger = 9007199254740991;

  final String mode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String attemptState;
  final String commandID;
  final String commandSHA256;
  final String targetID;
  final int leaseEpoch;
  final bool activationAllowed;
  final bool runnerAuthorityAccepted;
  final bool dispatchAdmissionReady;
  final bool transportAdmissionReady;
  final String effectState;
  final bool effectStateStartable;
  final bool cancellationClear;
  final bool executionBoundaryReady;
  final List<String> rejectionReasons;
  final ForgeRunnerExecutionBoundaryAuthority authority;

  const ForgeRunnerExecutionBoundaryObservation({
    required this.mode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.attemptState,
    required this.commandID,
    required this.commandSHA256,
    required this.targetID,
    required this.leaseEpoch,
    required this.activationAllowed,
    required this.runnerAuthorityAccepted,
    required this.dispatchAdmissionReady,
    required this.transportAdmissionReady,
    required this.effectState,
    required this.effectStateStartable,
    required this.cancellationClear,
    required this.executionBoundaryReady,
    required this.rejectionReasons,
    required this.authority,
  });

  factory ForgeRunnerExecutionBoundaryObservation.fromJsonText(String source) {
    rejectDuplicateForgeJsonKeys(source);
    return ForgeRunnerExecutionBoundaryObservation.fromJson(jsonDecode(source));
  }

  factory ForgeRunnerExecutionBoundaryObservation.fromJson(Object? value) {
    final json = _boundaryObject(value, 'Runner execution boundary');
    _boundaryExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'mode',
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'attempt_state',
      'command_id',
      'command_sha256',
      'target_id',
      'lease_epoch',
      'activation_allowed',
      'runner_authority_accepted',
      'dispatch_admission_ready',
      'transport_admission_ready',
      'effect_state',
      'effect_state_startable',
      'cancellation_clear',
      'execution_boundary_ready',
      'rejection_reasons',
      'preview_only',
      'authority',
    }, 'Runner execution boundary');
    if (json['schema_version'] != schema ||
        json['evaluation_mode'] != evaluationMode ||
        json['preview_only'] != true) {
      throw const FormatException(
        'Invalid Runner execution boundary envelope.',
      );
    }
    final mode = _boundaryMode(json['mode']);
    final attemptState = _boundaryState(json['attempt_state']);
    final effectState = _boundaryEffectState(json['effect_state']);
    final reasons = _boundaryReasons(json['rejection_reasons']);
    final result = ForgeRunnerExecutionBoundaryObservation(
      mode: mode,
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _boundaryIdentifier(json['conversation_id']),
      runID: _boundaryIdentifier(json['run_id']),
      attemptID: _boundaryIdentifier(json['attempt_id']),
      attemptState: attemptState,
      commandID: _boundaryIdentifier(json['command_id']),
      commandSHA256: _boundaryDigest(json['command_sha256']),
      targetID: _boundaryIdentifier(json['target_id']),
      leaseEpoch: _boundaryPositiveInt(json, 'lease_epoch'),
      activationAllowed: _boundaryBool(json, 'activation_allowed'),
      runnerAuthorityAccepted: _boundaryBool(json, 'runner_authority_accepted'),
      dispatchAdmissionReady: _boundaryBool(json, 'dispatch_admission_ready'),
      transportAdmissionReady: _boundaryBool(json, 'transport_admission_ready'),
      effectState: effectState,
      effectStateStartable: _boundaryBool(json, 'effect_state_startable'),
      cancellationClear: _boundaryBool(json, 'cancellation_clear'),
      executionBoundaryReady: _boundaryBool(json, 'execution_boundary_ready'),
      rejectionReasons: reasons,
      authority: ForgeRunnerExecutionBoundaryAuthority.fromJson(
        json['authority'],
      ),
    );
    final ready =
        mode == 'execute' &&
        result.activationAllowed &&
        result.runnerAuthorityAccepted &&
        result.dispatchAdmissionReady &&
        result.transportAdmissionReady &&
        result.effectStateStartable &&
        result.cancellationClear;
    if (result.effectStateStartable != _boundaryStartable(effectState) ||
        result.executionBoundaryReady != ready ||
        (ready && reasons.isNotEmpty) ||
        (!ready && reasons.isEmpty) ||
        (!result.dispatchAdmissionReady &&
            !reasons.contains('dispatch_admission_not_ready')) ||
        (!result.transportAdmissionReady &&
            !reasons.contains('transport_admission_not_ready')) ||
        (!result.cancellationClear &&
            !reasons.contains('cancellation_requested')) ||
        (!result.effectStateStartable &&
            !reasons.contains('effect_state_not_startable') &&
            !reasons.contains('uncertain_effect_requires_reconciliation'))) {
      throw const FormatException('Invalid Runner execution boundary binding.');
    }
    return result;
  }

  bool get isDisplayOnly => authority.isClear;

  bool isFor(String conversationID, String runID, String attemptID) =>
      this.conversationID == conversationID &&
      this.runID == runID &&
      this.attemptID == attemptID;

  Map<String, dynamic> toJson() => {
    'schema_version': schema,
    'evaluation_mode': evaluationMode,
    'mode': mode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'attempt_state': attemptState,
    'command_id': commandID,
    'command_sha256': commandSHA256,
    'target_id': targetID,
    'lease_epoch': leaseEpoch,
    'activation_allowed': activationAllowed,
    'runner_authority_accepted': runnerAuthorityAccepted,
    'dispatch_admission_ready': dispatchAdmissionReady,
    'transport_admission_ready': transportAdmissionReady,
    'effect_state': effectState,
    'effect_state_startable': effectStateStartable,
    'cancellation_clear': cancellationClear,
    'execution_boundary_ready': executionBoundaryReady,
    'rejection_reasons': rejectionReasons,
    'preview_only': true,
    'authority': authority.toJson(),
  };
}
