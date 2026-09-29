import 'forge_device_inventory_declaration.dart';
import 'forge_session_placement.dart';

part 'forge_run_intent_observation_validation.dart';

const forgeRunIntentObservationSchema = 'forge.run-intent-observation/v1';
const forgeRunIntentMaxSafeInteger = 9007199254740991;

/// Payload-free receipt returned after a prompt intent was accepted. This
/// value does not create a Run or read Hub state.
class ForgeRunIntentPromptReceipt {
  final String promptID;
  final String conversationID;
  final String role;
  final int acceptedAtMS;
  final String intentID;
  final String initialEventID;
  final int initialEventSequence;
  final String initialEventType;
  final bool replayed;

  const ForgeRunIntentPromptReceipt({
    required this.promptID,
    required this.conversationID,
    required this.role,
    required this.acceptedAtMS,
    required this.intentID,
    required this.initialEventID,
    required this.initialEventSequence,
    required this.initialEventType,
    required this.replayed,
  });
}

/// Sanitized Run summary observed for a prompt receipt. It is an existing
/// reference and never a command to create or start a Run.
class ForgeRunIntentRunReference {
  final String runID;
  final String conversationID;
  final String promptID;
  final int createdAtMS;
  final int latestSequence;
  final String status;

  const ForgeRunIntentRunReference({
    required this.runID,
    required this.conversationID,
    required this.promptID,
    required this.createdAtMS,
    required this.latestSequence,
    required this.status,
  });
}

class ForgeRunIntentObservationRequest {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final ForgeRunIntentPromptReceipt prompt;
  final ForgeRunIntentRunReference run;
  final ForgeSessionPlacementObservation placement;

  const ForgeRunIntentObservationRequest({
    required this.owner,
    required this.conversationID,
    required this.prompt,
    required this.run,
    required this.placement,
  });
}

class ForgeRunIntentObservation {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String promptID;
  final String intentID;
  final String runID;
  final bool promptAccepted;
  final bool runReferenceObserved;
  final bool promptRunBindingValid;
  final bool placementObservationBound;
  final bool previewOnly;
  final bool intentReplayed;
  final String runStatus;
  final int runLatestSequence;
  final int promptAcceptedAtMS;
  final int placementEvaluatedAtMS;
  final int placementDecisionCount;
  final int eligibleInstanceCount;
  final bool ownerDeclarationUnverified;
  final bool deviceAttributesUnverified;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final ForgeSessionPlacementAuthority authority;

  const ForgeRunIntentObservation({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.promptID,
    required this.intentID,
    required this.runID,
    required this.promptAccepted,
    required this.runReferenceObserved,
    required this.promptRunBindingValid,
    required this.placementObservationBound,
    required this.previewOnly,
    required this.intentReplayed,
    required this.runStatus,
    required this.runLatestSequence,
    required this.promptAcceptedAtMS,
    required this.placementEvaluatedAtMS,
    required this.placementDecisionCount,
    required this.eligibleInstanceCount,
    required this.ownerDeclarationUnverified,
    required this.deviceAttributesUnverified,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.authority,
  });

  /// Consumes the canonical metadata-only observation envelope. This parser
  /// accepts only values that can be rendered as an offline preview; it never
  /// turns an authority-bearing or target-bearing value into a UI model.
  factory ForgeRunIntentObservation.fromJson(Object? value) {
    final json = _runIntentObject(value);
    const envelopeKeys = {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'prompt_id',
      'intent_id',
      'run_id',
      'prompt_accepted',
      'run_reference_observed',
      'prompt_run_binding_valid',
      'placement_observation_bound',
      'preview_only',
      'intent_replayed',
      'run_status',
      'run_latest_sequence',
      'prompt_accepted_at_ms',
      'placement_evaluated_at_ms',
      'placement_decision_count',
      'eligible_instance_count',
      'owner_declaration_unverified',
      'device_attributes_unverified',
      'selected_device_id',
      'selected_instance_id',
      'authority',
    };
    // The standalone Rust preview command adds a fixed framing pair so its
    // output can be identified when mixed with other local command output.
    // Accept that pair only when it is exact; the canonical re-encoding below
    // intentionally omits the local framing.
    if (json.containsKey('v') || json.containsKey('type')) {
      if (json.length != envelopeKeys.length + 2 ||
          json['v'] != 1 ||
          json['type'] != 'device_run_intent_preview') {
        throw const FormatException('Invalid Forge Run-intent framing.');
      }
      json.remove('v');
      json.remove('type');
    }
    _runIntentExactKeys(json, envelopeKeys);
    final observation = ForgeRunIntentObservation(
      schemaVersion: _runIntentSchema(json['schema_version']),
      evaluationMode: _runIntentMode(json['evaluation_mode']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _runIntentIdentifier(json['conversation_id']),
      promptID: _runIntentIdentifier(json['prompt_id']),
      intentID: _runIntentIdentifier(json['intent_id']),
      runID: _runIntentIdentifier(json['run_id']),
      promptAccepted: _runIntentBool(json['prompt_accepted']),
      runReferenceObserved: _runIntentBool(json['run_reference_observed']),
      promptRunBindingValid: _runIntentBool(json['prompt_run_binding_valid']),
      placementObservationBound: _runIntentBool(
        json['placement_observation_bound'],
      ),
      previewOnly: _runIntentBool(json['preview_only']),
      intentReplayed: _runIntentBool(json['intent_replayed']),
      runStatus: _runIntentStatus(json['run_status']),
      runLatestSequence: _runIntentPositiveInteger(json['run_latest_sequence']),
      promptAcceptedAtMS: _runIntentNonNegativeInteger(
        json['prompt_accepted_at_ms'],
      ),
      placementEvaluatedAtMS: _runIntentPositiveInteger(
        json['placement_evaluated_at_ms'],
      ),
      placementDecisionCount: _runIntentCount(json['placement_decision_count']),
      eligibleInstanceCount: _runIntentCount(json['eligible_instance_count']),
      ownerDeclarationUnverified: _runIntentBool(
        json['owner_declaration_unverified'],
      ),
      deviceAttributesUnverified: _runIntentBool(
        json['device_attributes_unverified'],
      ),
      selectedDeviceID: _runIntentNullableIdentifier(
        json['selected_device_id'],
      ),
      selectedInstanceID: _runIntentNullableIdentifier(
        json['selected_instance_id'],
      ),
      authority: ForgeSessionPlacementAuthority.fromJson(json['authority']),
    );
    if (!observation.isDisplayOnly ||
        observation.eligibleInstanceCount >
            observation.placementDecisionCount) {
      throw const FormatException(
        'Forge Run-intent observation claims a target or authority.',
      );
    }
    return observation;
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'prompt_id': promptID,
    'intent_id': intentID,
    'run_id': runID,
    'prompt_accepted': promptAccepted,
    'run_reference_observed': runReferenceObserved,
    'prompt_run_binding_valid': promptRunBindingValid,
    'placement_observation_bound': placementObservationBound,
    'preview_only': previewOnly,
    'intent_replayed': intentReplayed,
    'run_status': runStatus,
    'run_latest_sequence': runLatestSequence,
    'prompt_accepted_at_ms': promptAcceptedAtMS,
    'placement_evaluated_at_ms': placementEvaluatedAtMS,
    'placement_decision_count': placementDecisionCount,
    'eligible_instance_count': eligibleInstanceCount,
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'device_attributes_unverified': deviceAttributesUnverified,
    'selected_device_id': selectedDeviceID,
    'selected_instance_id': selectedInstanceID,
    'authority': authority.toJson(),
  };

  /// Returns true only for the Conversation/Run that this value declares.
  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  /// Guards the widget boundary against a caller constructing a value without
  /// first using [observeForgeRunIntent]. The Sessions screen must never turn
  /// a mutated observation into a selection or execution affordance.
  bool get isDisplayOnly =>
      schemaVersion == forgeRunIntentObservationSchema &&
      evaluationMode == 'offline_static_only' &&
      promptAccepted &&
      runReferenceObserved &&
      promptRunBindingValid &&
      placementObservationBound &&
      previewOnly &&
      ownerDeclarationUnverified &&
      deviceAttributesUnverified &&
      selectedDeviceID == null &&
      selectedInstanceID == null &&
      !authority.identityVerified &&
      !authority.heartbeatPersisted &&
      !authority.inventoryAuthoritative &&
      !authority.reservationCreated &&
      !authority.executionAuthorized &&
      !authority.dispatchPerformed;
}

class ForgeRunIntentObservationError implements Exception {
  final String code;

  const ForgeRunIntentObservationError(this.code);
}

/// Binds an accepted prompt receipt and existing Run summary to an existing
/// offline placement observation. It has no clock, storage, network,
/// selection, reservation, execution, or dispatch effect.
ForgeRunIntentObservation observeForgeRunIntent(
  ForgeRunIntentObservationRequest request,
) {
  if (!_identifier(request.conversationID) ||
      request.owner != request.placement.owner ||
      request.placement.conversationID != request.conversationID) {
    throw const ForgeRunIntentObservationError('invalid_binding');
  }
  final prompt = request.prompt;
  if (!_identifier(prompt.promptID) ||
      prompt.conversationID != request.conversationID ||
      prompt.role != 'user' ||
      prompt.acceptedAtMS < 0 ||
      prompt.acceptedAtMS > forgeRunIntentMaxSafeInteger ||
      !_identifier(prompt.intentID) ||
      !_identifier(prompt.initialEventID) ||
      prompt.initialEventSequence != 1 ||
      prompt.initialEventType != 'submitted') {
    throw const ForgeRunIntentObservationError('invalid_receipt');
  }
  final run = request.run;
  if (!_identifier(run.runID) ||
      run.conversationID != request.conversationID ||
      run.promptID != prompt.promptID ||
      run.createdAtMS < prompt.acceptedAtMS ||
      run.createdAtMS > forgeRunIntentMaxSafeInteger ||
      run.latestSequence < 1 ||
      run.latestSequence > forgeRunIntentMaxSafeInteger ||
      !_runStatus(run.status)) {
    throw const ForgeRunIntentObservationError('invalid_binding');
  }
  final placement = request.placement;
  final authority = placement.authority;
  if (placement.schemaVersion != forgeSessionPlacementObservationSchema ||
      placement.evaluationMode != 'offline_static_only' ||
      placement.owner != request.owner ||
      placement.conversationID != request.conversationID ||
      placement.runID != run.runID ||
      placement.evaluatedAtMS <= 0 ||
      placement.evaluatedAtMS > forgeRunIntentMaxSafeInteger ||
      !placement.ownerDeclarationUnverified ||
      !placement.deviceAttributesUnverified ||
      placement.selectedDeviceID != null ||
      placement.selectedInstanceID != null ||
      authority.identityVerified ||
      authority.heartbeatPersisted ||
      authority.inventoryAuthoritative ||
      authority.reservationCreated ||
      authority.executionAuthorized ||
      authority.dispatchPerformed) {
    throw const ForgeRunIntentObservationError('invalid_placement');
  }
  final devices = <String>{};
  final instances = <String>{};
  for (final decision in placement.decisions) {
    if (!_identifier(decision.deviceID) ||
        !_identifier(decision.instanceID) ||
        !devices.add(decision.deviceID) ||
        !instances.add(decision.instanceID)) {
      throw const ForgeRunIntentObservationError('invalid_placement');
    }
  }
  return ForgeRunIntentObservation(
    schemaVersion: forgeRunIntentObservationSchema,
    evaluationMode: placement.evaluationMode,
    owner: request.owner,
    conversationID: request.conversationID,
    promptID: prompt.promptID,
    intentID: prompt.intentID,
    runID: run.runID,
    promptAccepted: true,
    runReferenceObserved: true,
    promptRunBindingValid: true,
    placementObservationBound: true,
    previewOnly: true,
    intentReplayed: prompt.replayed,
    runStatus: run.status,
    runLatestSequence: run.latestSequence,
    promptAcceptedAtMS: prompt.acceptedAtMS,
    placementEvaluatedAtMS: placement.evaluatedAtMS,
    placementDecisionCount: placement.decisions.length,
    eligibleInstanceCount: placement.decisions
        .where((decision) => decision.matchesRequirements)
        .length,
    ownerDeclarationUnverified: true,
    deviceAttributesUnverified: true,
    selectedDeviceID: null,
    selectedInstanceID: null,
    authority: const ForgeSessionPlacementAuthority.offline(),
  );
}
