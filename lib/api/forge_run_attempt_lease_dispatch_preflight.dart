import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_device_placement.dart';
import 'forge_preflight_fixture.dart';
import 'forge_runner_execution_intent.dart';
import 'forge_runner_lease_fencing.dart';

/// The private, stateless candidate route is intentionally opt-in. The
/// callback is supplied by a caller that has an accepted candidate seam; the
/// Sessions screen never constructs one from its bearer token.
typedef ForgeRunAttemptLeaseDispatchPreflightReader =
    Future<ForgePreflightFixture> Function(
      ForgeRunAttemptLeaseDispatchPreflightRequest request,
    );

/// Typed request for the Run → Attempt → lease → dispatch preflight
/// candidate. Every nested value is a caller-supplied declaration. The
/// request does not read a Run or Attempt store, issue a lease, select a
/// target, reserve capacity, or dispatch work.
class ForgeRunAttemptLeaseDispatchPreflightRequest {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String runStatus;
  final ForgeRunAttemptLeaseDispatchPlan dispatchPlan;

  const ForgeRunAttemptLeaseDispatchPreflightRequest({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.runStatus,
    required this.dispatchPlan,
  });

  factory ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(Object? value) {
    final json = _preflightObject(value, 'request');
    _preflightExactKeys(json, {
      'owner',
      'conversation_id',
      'run_id',
      'run_status',
      'dispatch_plan',
    });
    final owner = ForgeDeviceOwner.fromJson(json['owner']);
    final conversationID = _preflightIdentifier(json['conversation_id']);
    final runID = _preflightIdentifier(json['run_id']);
    final runStatus = _preflightRunStatus(json['run_status']);
    final dispatchPlan = ForgeRunAttemptLeaseDispatchPlan.fromJson(
      json['dispatch_plan'],
    );
    if (dispatchPlan.placement.owner != owner ||
        dispatchPlan.runnerExecutionIntent.owner != owner ||
        dispatchPlan.runnerExecutionIntent.conversationID != conversationID ||
        dispatchPlan.runnerExecutionIntent.runID != runID ||
        dispatchPlan.runnerExecutionIntent.targetID !=
            dispatchPlan.lease.targetID ||
        dispatchPlan.runnerExecutionIntent.attemptID !=
            dispatchPlan.lease.attemptID) {
      throw const FormatException(
        'Forge preflight request has mismatched owner or identity.',
      );
    }
    return ForgeRunAttemptLeaseDispatchPreflightRequest(
      owner: owner,
      conversationID: conversationID,
      runID: runID,
      runStatus: runStatus,
      dispatchPlan: dispatchPlan,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'run_status': runStatus,
    'dispatch_plan': dispatchPlan.toJson(),
  };

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;
}

/// Typed nested dispatch-plan declaration accepted by the preflight route.
class ForgeRunAttemptLeaseDispatchPlan {
  final String attemptState;
  final ForgeDevicePlacementRequest placement;
  final ForgeRunnerExecutionIntentObservation runnerExecutionIntent;
  final ForgeRunnerLeaseGrant lease;

  const ForgeRunAttemptLeaseDispatchPlan({
    required this.attemptState,
    required this.placement,
    required this.runnerExecutionIntent,
    required this.lease,
  });

  factory ForgeRunAttemptLeaseDispatchPlan.fromJson(Object? value) {
    final json = _preflightObject(value, 'dispatch_plan');
    _preflightExactKeys(json, {
      'attempt_state',
      'placement_request',
      'runner_execution_intent',
      'lease',
    });
    final attemptState = _preflightAttemptState(json['attempt_state']);
    final placement = ForgeDevicePlacementRequest.fromJson(
      json['placement_request'],
    );
    final runnerExecutionIntent =
        ForgeRunnerExecutionIntentObservation.fromJson(
          json['runner_execution_intent'],
        );
    final lease = ForgeRunnerLeaseGrant.fromJson(json['lease']);
    final maxSafe = BigInt.from(9007199254740991);
    if (lease.epoch > maxSafe ||
        lease.issuedAtMS > maxSafe ||
        lease.expiresAtMS > maxSafe) {
      throw const FormatException(
        'Forge preflight lease exceeds the JSON safe integer range.',
      );
    }
    return ForgeRunAttemptLeaseDispatchPlan(
      attemptState: attemptState,
      placement: placement,
      runnerExecutionIntent: runnerExecutionIntent,
      lease: lease,
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_state': attemptState,
    'placement_request': placement.toJson(),
    'runner_execution_intent': runnerExecutionIntent.toJson(),
    'lease': lease.toJson(),
  };
}

Map<String, dynamic> _preflightObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Forge preflight $label must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

void _preflightExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge preflight fields.');
  }
}

String _preflightIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      utf8.encode(value).length > 85 ||
      !_preflightIdentifierCodeUnits(value)) {
    throw const FormatException('Invalid Forge preflight identifier.');
  }
  return value;
}

bool _preflightIdentifierCodeUnits(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) ||
      code == 0x2e ||
      code == 0x5f ||
      code == 0x2b ||
      code == 0x2d;
  final codes = value.codeUnits;
  return codes.isNotEmpty && first(codes.first) && codes.skip(1).every(rest);
}

String _preflightRunStatus(Object? value) {
  const values = {
    'nonterminal',
    'completed',
    'cancelled',
    'limit_exceeded',
    'failed',
  };
  if (value is! String || !values.contains(value)) {
    throw const FormatException('Invalid Forge preflight Run status.');
  }
  return value;
}

String _preflightAttemptState(Object? value) {
  const values = {
    'requested',
    'accepted',
    'starting',
    'running',
    'interrupted',
    'completed',
    'failed',
    'uncertain',
  };
  if (value is! String || !values.contains(value)) {
    throw const FormatException('Invalid Forge preflight Attempt state.');
  }
  return value;
}
