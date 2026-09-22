import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_intent_observation.dart';
import 'package:sso_admin/api/forge_session_placement.dart';

void main() {
  final runPath =
      Platform.environment['FORGE_RUN_INTENT_OBSERVATION_CONTRACT_FIXTURE'];
  final placementPath =
      Platform.environment['FORGE_SESSION_PLACEMENT_CONTRACT_FIXTURE'];

  test(
    'binds prompt receipt and Run reference to shared placement observation',
    () => _assertFixture(runPath!, placementPath!),
    skip: runPath == null || placementPath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects a placement observation that claims authority', () {
    const owner = ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'user-1',
      tenantID: 'tenant-1',
    );
    final placement = ForgeSessionPlacementObservation(
      schemaVersion: forgeSessionPlacementObservationSchema,
      evaluationMode: 'offline_static_only',
      owner: owner,
      conversationID: 'conversation-1',
      runID: 'run-1',
      evaluatedAtMS: 10,
      ownerDeclarationUnverified: true,
      deviceAttributesUnverified: true,
      decisions: const [],
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: const ForgeSessionPlacementAuthority(
        identityVerified: false,
        heartbeatPersisted: false,
        inventoryAuthoritative: false,
        reservationCreated: false,
        executionAuthorized: true,
        dispatchPerformed: false,
      ),
    );
    expect(
      () => observeForgeRunIntent(
        ForgeRunIntentObservationRequest(
          owner: owner,
          conversationID: 'conversation-1',
          prompt: const ForgeRunIntentPromptReceipt(
            promptID: 'prompt-1',
            conversationID: 'conversation-1',
            role: 'user',
            acceptedAtMS: 10,
            intentID: 'intent-1',
            initialEventID: 'event-1',
            initialEventSequence: 1,
            initialEventType: 'submitted',
            replayed: false,
          ),
          run: const ForgeRunIntentRunReference(
            runID: 'run-1',
            conversationID: 'conversation-1',
            promptID: 'prompt-1',
            createdAtMS: 10,
            latestSequence: 1,
            status: 'nonterminal',
          ),
          placement: placement,
        ),
      ),
      throwsA(
        isA<ForgeRunIntentObservationError>().having(
          (error) => error.code,
          'code',
          'invalid_placement',
        ),
      ),
    );
  });

  test('rejects unknown, selected-target, and unsafe envelope mutations', () {
    final json = _safeEnvelope();
    final framed = <String, dynamic>{
      'v': 1,
      'type': 'device_run_intent_preview',
      ...json,
    };
    expect(ForgeRunIntentObservation.fromJson(framed).toJson(), json);
    expect(
      () => ForgeRunIntentObservation.fromJson({...framed, 'type': 'other'}),
      throwsFormatException,
    );
    expect(
      () => ForgeRunIntentObservation.fromJson({...json, 'unexpected': true}),
      throwsFormatException,
    );
    expect(
      () => ForgeRunIntentObservation.fromJson({
        ...json,
        'selected_device_id': 'device-1',
      }),
      throwsFormatException,
    );
    expect(
      () => ForgeRunIntentObservation.fromJson({
        ...json,
        'authority': {
          ...Map<String, dynamic>.from(json['authority'] as Map),
          'execution_authorized': true,
        },
      }),
      throwsFormatException,
    );
    expect(
      () => ForgeRunIntentObservation.fromJson({
        ...json,
        'run_latest_sequence': forgeRunIntentMaxSafeInteger + 1,
      }),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _safeEnvelope() => {
  'schema_version': forgeRunIntentObservationSchema,
  'evaluation_mode': 'offline_static_only',
  'owner': const ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-1',
    tenantID: 'tenant-1',
  ).toJson(),
  'conversation_id': 'conversation-1',
  'prompt_id': 'prompt-1',
  'intent_id': 'intent-1',
  'run_id': 'run-1',
  'prompt_accepted': true,
  'run_reference_observed': true,
  'prompt_run_binding_valid': true,
  'placement_observation_bound': true,
  'preview_only': true,
  'intent_replayed': false,
  'run_status': 'nonterminal',
  'run_latest_sequence': 1,
  'prompt_accepted_at_ms': 10,
  'placement_evaluated_at_ms': 20,
  'placement_decision_count': 0,
  'eligible_instance_count': 0,
  'owner_declaration_unverified': true,
  'device_attributes_unverified': true,
  'selected_device_id': null,
  'selected_instance_id': null,
  'authority': const ForgeSessionPlacementAuthority.offline().toJson(),
};

void _assertFixture(String runPath, String placementPath) {
  final runRoot = _readObject(runPath);
  _exactKeys(runRoot, {
    'api_version',
    'placement_contract_fixture',
    'owner',
    'conversation_id',
    'prompt_receipt',
    'run_reference',
    'expected',
  });
  expect(runRoot['api_version'], 'forgeos.run-intent-observation-contract/v1');
  expect(
    runRoot['placement_contract_fixture'],
    'forge-session-placement-observation-v1',
  );
  final owner = ForgeDeviceOwner.fromJson(runRoot['owner']);
  final promptJSON = _asObject(runRoot['prompt_receipt']);
  _exactKeys(promptJSON, {
    'prompt_id',
    'conversation_id',
    'role',
    'accepted_at_ms',
    'intent_id',
    'initial_event_id',
    'initial_event_sequence',
    'initial_event_type',
    'replayed',
  });
  final prompt = ForgeRunIntentPromptReceipt(
    promptID: promptJSON['prompt_id'] as String,
    conversationID: promptJSON['conversation_id'] as String,
    role: promptJSON['role'] as String,
    acceptedAtMS: promptJSON['accepted_at_ms'] as int,
    intentID: promptJSON['intent_id'] as String,
    initialEventID: promptJSON['initial_event_id'] as String,
    initialEventSequence: promptJSON['initial_event_sequence'] as int,
    initialEventType: promptJSON['initial_event_type'] as String,
    replayed: promptJSON['replayed'] as bool,
  );
  final runJSON = _asObject(runRoot['run_reference']);
  _exactKeys(runJSON, {
    'run_id',
    'conversation_id',
    'prompt_id',
    'created_at_ms',
    'latest_sequence',
    'status',
  });
  final run = ForgeRunIntentRunReference(
    runID: runJSON['run_id'] as String,
    conversationID: runJSON['conversation_id'] as String,
    promptID: runJSON['prompt_id'] as String,
    createdAtMS: runJSON['created_at_ms'] as int,
    latestSequence: runJSON['latest_sequence'] as int,
    status: runJSON['status'] as String,
  );
  final placement = _readPlacementObservation(placementPath);
  final request = ForgeRunIntentObservationRequest(
    owner: owner,
    conversationID: runRoot['conversation_id'] as String,
    prompt: prompt,
    run: run,
    placement: placement,
  );
  final observation = observeForgeRunIntent(request);
  final roundTripped = ForgeRunIntentObservation.fromJson(observation.toJson());
  expect(roundTripped.toJson(), observation.toJson());
  final expected = _asObject(runRoot['expected']);
  _exactKeys(expected, {
    'evaluation_mode',
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
  });
  expect(observation.schemaVersion, forgeRunIntentObservationSchema);
  expect(observation.evaluationMode, expected['evaluation_mode']);
  expect(observation.owner, owner);
  expect(observation.conversationID, request.conversationID);
  expect(observation.promptID, prompt.promptID);
  expect(observation.intentID, prompt.intentID);
  expect(observation.runID, run.runID);
  expect(observation.promptAccepted, expected['prompt_accepted']);
  expect(observation.runReferenceObserved, expected['run_reference_observed']);
  expect(
    observation.promptRunBindingValid,
    expected['prompt_run_binding_valid'],
  );
  expect(
    observation.placementObservationBound,
    expected['placement_observation_bound'],
  );
  expect(observation.previewOnly, expected['preview_only']);
  expect(observation.intentReplayed, expected['intent_replayed']);
  expect(observation.runStatus, expected['run_status']);
  expect(observation.runLatestSequence, expected['run_latest_sequence']);
  expect(observation.promptAcceptedAtMS, expected['prompt_accepted_at_ms']);
  expect(
    observation.placementEvaluatedAtMS,
    expected['placement_evaluated_at_ms'],
  );
  expect(
    observation.placementDecisionCount,
    expected['placement_decision_count'],
  );
  expect(
    observation.eligibleInstanceCount,
    expected['eligible_instance_count'],
  );
  expect(
    observation.ownerDeclarationUnverified,
    expected['owner_declaration_unverified'],
  );
  expect(
    observation.deviceAttributesUnverified,
    expected['device_attributes_unverified'],
  );
  expect(observation.selectedDeviceID, expected['selected_device_id']);
  expect(observation.selectedInstanceID, expected['selected_instance_id']);
  expect(observation.authority.toJson(), expected['authority']);
}

ForgeSessionPlacementObservation _readPlacementObservation(String path) {
  final root = _readObject(path);
  _exactKeys(root, {
    'api_version',
    'owner',
    'conversation_id',
    'run_id',
    'placement',
    'expected',
  });
  final expected = _asObject(root['expected']);
  _exactKeys(expected, {
    'evaluation_mode',
    'evaluated_at_ms',
    'owner_declaration_unverified',
    'device_attributes_unverified',
    'decisions',
    'selected_device_id',
    'selected_instance_id',
    'authority',
  });
  final decisions = (expected['decisions'] as List)
      .map((value) {
        final decision = _asObject(value);
        _exactKeys(decision, {
          'device_id',
          'instance_id',
          'matches_requirements',
          'exclusion_reasons',
        });
        return ForgeSessionPlacementDecision(
          deviceID: decision['device_id'] as String,
          instanceID: decision['instance_id'] as String,
          matchesRequirements: decision['matches_requirements'] as bool,
          exclusionReasons: List<String>.from(
            decision['exclusion_reasons'] as List,
          ),
        );
      })
      .toList(growable: false);
  final authority = _asObject(expected['authority']);
  _exactKeys(authority, {
    'identity_verified',
    'heartbeat_persisted',
    'inventory_authoritative',
    'reservation_created',
    'execution_authorized',
    'dispatch_performed',
  });
  return ForgeSessionPlacementObservation(
    schemaVersion: forgeSessionPlacementObservationSchema,
    evaluationMode: expected['evaluation_mode'] as String,
    owner: ForgeDeviceOwner.fromJson(root['owner']),
    conversationID: root['conversation_id'] as String,
    runID: root['run_id'] as String,
    evaluatedAtMS: expected['evaluated_at_ms'] as int,
    ownerDeclarationUnverified:
        expected['owner_declaration_unverified'] as bool,
    deviceAttributesUnverified:
        expected['device_attributes_unverified'] as bool,
    decisions: List.unmodifiable(decisions),
    selectedDeviceID: expected['selected_device_id'] as String?,
    selectedInstanceID: expected['selected_instance_id'] as String?,
    authority: ForgeSessionPlacementAuthority(
      identityVerified: authority['identity_verified'] as bool,
      heartbeatPersisted: authority['heartbeat_persisted'] as bool,
      inventoryAuthoritative: authority['inventory_authoritative'] as bool,
      reservationCreated: authority['reservation_created'] as bool,
      executionAuthorized: authority['execution_authorized'] as bool,
      dispatchPerformed: authority['dispatch_performed'] as bool,
    ),
  );
}

Map<String, dynamic> _readObject(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

Map<String, dynamic> _asObject(Object? value) {
  if (value is! Map) throw const FormatException('Expected object.');
  return Map<String, dynamic>.from(value);
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Run intent fields.');
  }
}
