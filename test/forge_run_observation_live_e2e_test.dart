import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/api/forge_session_device_observation_wire.dart';
import 'package:sso_admin/api/forge_run_observed.dart';

void main() {
  final inputPath = Platform.environment['FORGE_RUN_OBSERVATION_E2E_INPUT'];

  test(
    'Flutter Forge API observes an owner-scoped Run and metadata-only timeline',
    () async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final conversationID = input['conversation_id'];
      final runID = input['run_id'];
      if (apiURL is! String ||
          accessToken is! String ||
          conversationID is! String ||
          runID is! String ||
          apiURL.isEmpty ||
          accessToken.isEmpty ||
          conversationID.isEmpty ||
          runID.isEmpty) {
        throw const FormatException('Invalid Forge Run observation input.');
      }

      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        httpClient: http.Client(),
      );
      try {
        final runs = await api.listRuns(
          conversationID: conversationID,
          limit: ForgeConversationsApi.maxPageSize,
        );
        expect(runs.conversationID, conversationID);
        expect(runs.runs, hasLength(1));
        expect(runs.hasMore, isFalse);
        final run = runs.runs.single;
        expect(run.runID, runID);
        expect(run.promptID, isNotEmpty);
        expect(run.latestSequence, greaterThan(0));
        expect(run.status, 'completed');

        final runObservedMap = input['run_observed'];
        if (runObservedMap is Map) {
          final expectedObserved = ForgeRunObserved.fromJson(runObservedMap);
          final observed = await api.readRunObservedCandidate(
            conversationID: conversationID,
            runID: runID,
          );
          expect(observed.toJson(), expectedObserved.toJson());
          expect(observed.conversationID, conversationID);
          expect(observed.runID, runID);
          expect(observed.promptID, run.promptID);
          expect(observed.latestSequence, run.latestSequence);
          expect(observed.status, run.status);
          expect(observed.isDisplayOnly, isTrue);
        }

        final timeline = await api.listRunTimeline(
          conversationID: conversationID,
          runID: runID,
          afterSequence: 0,
          limit: ForgeConversationsApi.maxPageSize,
        );
        expect(timeline.conversationID, conversationID);
        expect(timeline.runID, runID);
        expect(timeline.afterSequence, 0);
        expect(timeline.events.length, greaterThanOrEqualTo(2));
        expect(timeline.events.first.sequence, 1);
        expect(timeline.events.first.type, 'run_started');
        expect(timeline.events.last.type, 'run_finished');
        expect(timeline.hasMore, isFalse);

        final placementMap = input['placement_request'];
        final sessionMap = input['session_device_observation_request'];
        final responseMap = input['session_device_observation_response'];
        if (placementMap is! Map && sessionMap is! Map) {
          throw const FormatException(
            'Missing session placement request in Run observation input.',
          );
        }
        final sessionRequest = sessionMap is Map
            ? _sessionPlacementRequestFromInput(sessionMap)
            : _singleDeviceSessionRequest(
                Map<String, dynamic>.from(placementMap as Map),
                conversationID,
                runID,
              );
        expect(sessionRequest.conversationID, conversationID);
        expect(sessionRequest.runID, runID);
        expect(sessionRequest.candidates, hasLength(9));
        final rustObservation = responseMap is Map
            ? ForgeSessionDeviceObservationWire.fromJson(responseMap)
            : null;
        if (rustObservation != null) {
          expect(rustObservation.owner, sessionRequest.owner);
          expect(rustObservation.conversationID, conversationID);
          expect(rustObservation.runID, runID);
          expect(rustObservation.evaluatedAtMS, 200000);
          expect(rustObservation.inventory.devices, hasLength(9));
          expect(rustObservation.placementObservation.decisions, hasLength(9));
          final inventoryPairs =
              rustObservation.inventory.devices
                  .map(
                    (candidate) =>
                        '${candidate.device.deviceID}/${candidate.instanceID}',
                  )
                  .toList()
                ..sort();
          final decisionPairs =
              rustObservation.placementObservation.decisions
                  .map(
                    (decision) => '${decision.deviceID}/${decision.instanceID}',
                  )
                  .toList()
                ..sort();
          expect(inventoryPairs, <String>[
            'candidate-a/runner-a',
            'candidate-b/runner-b',
            'candidate-c/runner-c',
            'candidate-d/runner-d',
            'candidate-e/runner-e',
            'candidate-f/runner-f',
            'candidate-g/runner-g',
            'candidate-h/runner-h',
            'candidate-i/runner-i',
          ]);
          expect(decisionPairs, inventoryPairs);
          expect(rustObservation.resourceSummary.deviceCount, 9);
          expect(rustObservation.resourceSummary.runnerInstanceCount, 9);
          expect(rustObservation.resourceSummary.availableCPUCores, 66);
          expect(rustObservation.resourceSummary.availableMemoryBytes, 135168);
          expect(rustObservation.resourceSummary.availableStorageBytes, 67584);
          expect(rustObservation.resourceSummary.eligibleDeviceCount, 2);
          expect(rustObservation.resourceSummary.eligibleInstanceCount, 2);
          expect(rustObservation.selectedDeviceID, isNull);
          expect(rustObservation.selectedInstanceID, isNull);
          expect(rustObservation.authority.identityVerified, isFalse);
          expect(rustObservation.authority.heartbeatPersisted, isFalse);
          expect(rustObservation.authority.inventoryAuthoritative, isFalse);
          expect(rustObservation.authority.reservationCreated, isFalse);
          expect(rustObservation.authority.executionAuthorized, isFalse);
          expect(rustObservation.authority.dispatchPerformed, isFalse);
        }
        final observation = await api.previewSessionDeviceObservation(
          request: sessionRequest,
        );
        if (rustObservation != null) {
          expect(
            jsonEncode(observation.toJson()),
            jsonEncode(rustObservation.toJson()),
          );
        }
        expect(observation.owner, sessionRequest.owner);
        expect(observation.conversationID, conversationID);
        expect(observation.runID, runID);
        expect(
          observation.evaluatedAtMS,
          sessionRequest.placement.evaluatedAtMS,
        );
        expect(observation.inventory.evaluatedAtMS, observation.evaluatedAtMS);
        expect(observation.inventory.devices, hasLength(9));
        expect(
          observation.inventory.devices
              .map((candidate) => candidate.device.deviceID)
              .toList(),
          sessionRequest.candidates
              .map((candidate) => candidate.device.deviceID)
              .toList(),
        );
        expect(
          observation.inventory.devices
              .map((candidate) => candidate.instanceID)
              .toList(),
          sessionRequest.candidates
              .map((candidate) => candidate.instanceID)
              .toList(),
        );
        expect(
          observation.placementObservation.decisions,
          hasLength(sessionRequest.candidates.length),
        );
        const expectedMatches = [
          true,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          true,
        ];
        for (var index = 0; index < sessionRequest.candidates.length; index++) {
          final candidate = sessionRequest.candidates[index];
          final decision = observation.placementObservation.decisions[index];
          expect(decision.deviceID, candidate.device.deviceID);
          expect(decision.instanceID, candidate.instanceID);
          expect(decision.matchesRequirements, expectedMatches[index]);
          expect(decision.exclusionReasons.isEmpty, expectedMatches[index]);
        }
        expect(observation.resourceSummary.deviceCount, 9);
        expect(observation.resourceSummary.runnerInstanceCount, 9);
        expect(observation.resourceSummary.availableCPUCores, 66);
        expect(observation.resourceSummary.availableMemoryBytes, 135168);
        expect(observation.resourceSummary.availableStorageBytes, 67584);
        expect(observation.resourceSummary.availableGPUCount, 0);
        expect(observation.resourceSummary.availableGPUMemoryBytes, 0);
        expect(observation.resourceSummary.eligibleDeviceCount, 2);
        expect(observation.resourceSummary.eligibleInstanceCount, 2);
        expect(
          observation.resourceSummary.evaluatedAtMS,
          observation.evaluatedAtMS,
        );
        expect(observation.placementObservation.selectedDeviceID, isNull);
        expect(observation.placementObservation.selectedInstanceID, isNull);
        expect(observation.authority.identityVerified, isFalse);
        expect(observation.authority.heartbeatPersisted, isFalse);
        expect(observation.authority.inventoryAuthoritative, isFalse);
        expect(observation.authority.reservationCreated, isFalse);
        expect(observation.authority.executionAuthorized, isFalse);
        expect(observation.authority.dispatchPerformed, isFalse);

        final receiptMap = input['session_runner_receipt_observation'];
        if (receiptMap is Map) {
          final receipt = ForgeSessionRunnerReceiptObservation.fromJson(
            receiptMap,
          );
          expect(receipt.conversationID, conversationID);
          expect(receipt.promptID, run.promptID);
          expect(receipt.runID, runID);
          expect(receipt.isDisplayOnly, isTrue);
          expect(receipt.selectedTargetID, isNull);
          expect(receipt.authority.isOffline, isTrue);
          final uncertain =
              receipt.receiptObservation.dispositionKind == 'uncertain';
          expect(receipt.receiptObservation.uncertain, uncertain);
          expect(receipt.receiptObservation.reconciliationRequired, uncertain);
          expect(receipt.receiptObservation.manualReviewRequired, uncertain);
          expect(receipt.receiptObservation.automaticRetry, isFalse);
          expect(
            receipt.receiptObservation.followUp,
            uncertain ? 'reconciliation_manual' : 'none',
          );
          final returned = await api.previewSessionRunnerReceiptObservation(
            conversationID: conversationID,
            runID: runID,
            observation: receipt,
          );
          expect(returned.conversationID, conversationID);
          expect(returned.promptID, run.promptID);
          expect(returned.runID, runID);
          expect(returned.receiptObservation.commandID, isNotEmpty);
          expect(returned.receiptObservation.commandSHA256, hasLength(64));
          expect(
            returned.receiptObservation.dispositionKind,
            receipt.receiptObservation.dispositionKind,
          );
          expect(returned.receiptObservation.uncertain, uncertain);
          expect(
            returned.receiptObservation.reconciliationRequired,
            uncertain,
          );
          expect(returned.receiptObservation.manualReviewRequired, uncertain);
          expect(returned.receiptObservation.automaticRetry, isFalse);
          expect(
            returned.receiptObservation.followUp,
            uncertain ? 'reconciliation_manual' : 'none',
          );
          expect(returned.authority.isOffline, isTrue);
        }
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the authenticated shared-session E2E.'
        : false,
  );
}

ForgeSessionPlacementRequest _sessionPlacementRequestFromInput(Map raw) {
  final json = Map<String, dynamic>.from(raw);
  final owner = ForgeDeviceOwner.fromJson(json['owner']);
  final conversationID = json['conversation_id'];
  final runID = json['run_id'];
  final placement = ForgeDevicePlacementRequest.fromJson(json['placement']);
  final rawCandidates = json['candidates'];
  if (conversationID is! String ||
      runID is! String ||
      rawCandidates is! List ||
      rawCandidates.length != placement.devices.length) {
    throw const FormatException('Invalid session observation request input.');
  }
  final candidates = rawCandidates
      .map((value) {
        final candidate = Map<String, dynamic>.from(value as Map);
        return ForgeSessionPlacementCandidate(
          instanceID: candidate['instance_id'] as String,
          device: ForgeDeviceDeclaration.fromJson(candidate['device']),
        );
      })
      .toList(growable: false);
  if (owner != placement.owner) {
    throw const FormatException('Session observation owner drifted.');
  }
  return ForgeSessionPlacementRequest(
    owner: owner,
    conversationID: conversationID,
    runID: runID,
    placement: placement,
    candidates: candidates,
  );
}

ForgeSessionPlacementRequest _singleDeviceSessionRequest(
  Map<String, dynamic> placementMap,
  String conversationID,
  String runID,
) {
  final placement = ForgeDevicePlacementRequest.fromJson(placementMap);
  return ForgeSessionPlacementRequest(
    owner: placement.owner,
    conversationID: conversationID,
    runID: runID,
    placement: placement,
    candidates: [
      ForgeSessionPlacementCandidate(
        instanceID: 'runner-1',
        device: placement.devices.single,
      ),
    ],
  );
}
