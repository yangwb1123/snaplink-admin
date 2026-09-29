import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';
import 'forge_runner_execution_intent.dart';

part 'forge_runner_dispatch_admission_validation.dart';

/// Request for the owner-authenticated, read-only lease-to-Runner recheck.
class ForgeRunnerDispatchAdmissionRequest {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String attemptState;
  final ForgeRunnerExecutionCommand command;
  final int evaluatedAtMS;

  const ForgeRunnerDispatchAdmissionRequest({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.attemptState,
    required this.command,
    required this.evaluatedAtMS,
  });

  factory ForgeRunnerDispatchAdmissionRequest.fromJson(Object? value) {
    final json = _admissionObject(value, 'Runner dispatch admission request');
    _admissionExactKeys(json, {
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'attempt_state',
      'command',
      'evaluated_at_ms',
    });
    final evaluated = _admissionInt(json['evaluated_at_ms'], 'evaluated_at_ms');
    if (evaluated <= 0 || evaluated > 9007199254740991) {
      throw const FormatException('Invalid Runner dispatch admission time.');
    }
    final owner = ForgeDeviceOwner.fromJson(json['owner']);
    final conversationID = _admissionIdentifier(json['conversation_id']);
    final runID = _admissionIdentifier(json['run_id']);
    final attemptID = _admissionIdentifier(json['attempt_id']);
    final state = _admissionState(json['attempt_state']);
    final command = _admissionCommand(json['command']);
    if (command.leaseProof.attemptID != attemptID) {
      throw const FormatException(
        'Runner dispatch admission proof is not bound to the Attempt.',
      );
    }
    return ForgeRunnerDispatchAdmissionRequest(
      owner: owner,
      conversationID: conversationID,
      runID: runID,
      attemptID: attemptID,
      attemptState: state,
      command: command,
      evaluatedAtMS: evaluated,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'attempt_state': attemptState,
    'command': {
      'v': command.version,
      'command_id': command.commandID,
      'lease_proof': {
        'attempt_id': command.leaseProof.attemptID,
        'target_id': command.leaseProof.targetID,
        'epoch': command.leaseProof.epoch,
        'fencing_token': command.leaseProof.fencingToken,
      },
      'idempotency_key': command.idempotencyKey,
      'workspace_ref': command.workspaceRef,
      'argv': command.argv,
      'timeout_ms': command.timeoutMS,
      'max_output_bytes': command.maxOutputBytes,
    },
    'evaluated_at_ms': evaluatedAtMS,
  };
}

class ForgeRunnerDispatchAdmissionAuthority {
  final bool deviceIdentityVerified;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeRunnerDispatchAdmissionAuthority({
    required this.deviceIdentityVerified,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeRunnerDispatchAdmissionAuthority.fromJson(Object? value) {
    final json = _admissionObject(value, 'Runner dispatch admission authority');
    _admissionExactKeys(json, {
      'device_identity_verified',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeRunnerDispatchAdmissionAuthority(
      deviceIdentityVerified: _admissionBool(json['device_identity_verified']),
      reservationCreated: _admissionBool(json['reservation_created']),
      executionAuthorized: _admissionBool(json['execution_authorized']),
      dispatchPerformed: _admissionBool(json['dispatch_performed']),
      auditPublished: _admissionBool(json['audit_published']),
    );
    if (authority.deviceIdentityVerified ||
        authority.reservationCreated ||
        authority.executionAuthorized ||
        authority.dispatchPerformed ||
        authority.auditPublished) {
      throw const FormatException(
        'Runner dispatch admission granted authority.',
      );
    }
    return authority;
  }
}

class ForgeRunnerDispatchAdmission {
  static const schema = 'forge.runner-dispatch-admission/v1';
  static const evaluationMode =
      'durable_lease_bound_dispatch_admission_preview';

  final String schemaVersion;
  final String mode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String attemptState;
  final bool attemptStateAdmissible;
  final String commandID;
  final String commandSHA256;
  final String targetID;
  final int leaseEpoch;
  final int leaseIssuedAtMS;
  final int leaseExpiresAtMS;
  final int evaluatedAtMS;
  final bool leaseProofCurrent;
  final bool leaseActive;
  final bool commandBindingValid;
  final bool admissionReady;
  final List<String> rejectionReasons;
  final bool previewOnly;
  final ForgeRunnerDispatchAdmissionAuthority authority;

  const ForgeRunnerDispatchAdmission({
    required this.schemaVersion,
    required this.mode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.attemptState,
    required this.attemptStateAdmissible,
    required this.commandID,
    required this.commandSHA256,
    required this.targetID,
    required this.leaseEpoch,
    required this.leaseIssuedAtMS,
    required this.leaseExpiresAtMS,
    required this.evaluatedAtMS,
    required this.leaseProofCurrent,
    required this.leaseActive,
    required this.commandBindingValid,
    required this.admissionReady,
    required this.rejectionReasons,
    required this.previewOnly,
    required this.authority,
  });

  factory ForgeRunnerDispatchAdmission.fromJsonText(String source) {
    rejectDuplicateForgeJsonKeys(source);
    return ForgeRunnerDispatchAdmission.fromJson(jsonDecode(source));
  }

  factory ForgeRunnerDispatchAdmission.fromJson(Object? value) {
    final json = _admissionObject(value, 'Runner dispatch admission');
    _admissionExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'attempt_state',
      'attempt_state_admissible',
      'command_id',
      'command_sha256',
      'target_id',
      'lease_epoch',
      'lease_issued_at_ms',
      'lease_expires_at_ms',
      'evaluated_at_ms',
      'lease_proof_current',
      'lease_active',
      'command_binding_valid',
      'admission_ready',
      'rejection_reasons',
      'preview_only',
      'authority',
    });
    final result = ForgeRunnerDispatchAdmission(
      schemaVersion: _admissionText(json['schema_version']),
      mode: _admissionText(json['evaluation_mode']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _admissionIdentifier(json['conversation_id']),
      runID: _admissionIdentifier(json['run_id']),
      attemptID: _admissionIdentifier(json['attempt_id']),
      attemptState: _admissionState(json['attempt_state']),
      attemptStateAdmissible: _admissionBool(json['attempt_state_admissible']),
      commandID: _admissionIdentifier(json['command_id']),
      commandSHA256: _admissionDigest(json['command_sha256']),
      targetID: _admissionIdentifier(json['target_id']),
      leaseEpoch: _admissionPositiveInt(json['lease_epoch']),
      leaseIssuedAtMS: _admissionPositiveInt(json['lease_issued_at_ms']),
      leaseExpiresAtMS: _admissionPositiveInt(json['lease_expires_at_ms']),
      evaluatedAtMS: _admissionPositiveInt(json['evaluated_at_ms']),
      leaseProofCurrent: _admissionBool(json['lease_proof_current']),
      leaseActive: _admissionBool(json['lease_active']),
      commandBindingValid: _admissionBool(json['command_binding_valid']),
      admissionReady: _admissionBool(json['admission_ready']),
      rejectionReasons: _admissionReasons(json['rejection_reasons']),
      previewOnly: _admissionBool(json['preview_only']),
      authority: ForgeRunnerDispatchAdmissionAuthority.fromJson(
        json['authority'],
      ),
    );
    if (result.schemaVersion != schema ||
        result.mode != evaluationMode ||
        result.leaseExpiresAtMS <= result.leaseIssuedAtMS ||
        result.admissionReady !=
            (result.commandBindingValid &&
                result.leaseProofCurrent &&
                result.leaseActive &&
                result.attemptStateAdmissible) ||
        result.attemptStateAdmissible !=
            const {
              'accepted',
              'starting',
              'running',
            }.contains(result.attemptState) ||
        result.rejectionReasons.join('|') !=
            _admissionReasonsFor(
              result.commandBindingValid,
              result.leaseProofCurrent,
              result.leaseActive,
              result.attemptStateAdmissible,
            ).join('|') ||
        !result.previewOnly) {
      throw const FormatException('Invalid Runner dispatch admission.');
    }
    return result;
  }

  bool get isDisplayOnly =>
      previewOnly &&
      !authority.deviceIdentityVerified &&
      !authority.reservationCreated &&
      !authority.executionAuthorized &&
      !authority.dispatchPerformed &&
      !authority.auditPublished;

  bool isFor(String conversationID, String runID, String attemptID) =>
      this.conversationID == conversationID &&
      this.runID == runID &&
      this.attemptID == attemptID;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': mode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'attempt_state': attemptState,
    'attempt_state_admissible': attemptStateAdmissible,
    'command_id': commandID,
    'command_sha256': commandSHA256,
    'target_id': targetID,
    'lease_epoch': leaseEpoch,
    'lease_issued_at_ms': leaseIssuedAtMS,
    'lease_expires_at_ms': leaseExpiresAtMS,
    'evaluated_at_ms': evaluatedAtMS,
    'lease_proof_current': leaseProofCurrent,
    'lease_active': leaseActive,
    'command_binding_valid': commandBindingValid,
    'admission_ready': admissionReady,
    'rejection_reasons': rejectionReasons,
    'preview_only': previewOnly,
    'authority': {
      'device_identity_verified': authority.deviceIdentityVerified,
      'reservation_created': authority.reservationCreated,
      'execution_authorized': authority.executionAuthorized,
      'dispatch_performed': authority.dispatchPerformed,
      'audit_published': authority.auditPublished,
    },
  };
}
