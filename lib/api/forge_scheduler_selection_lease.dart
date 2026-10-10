import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_device_placement.dart';

part 'forge_scheduler_selection_lease_grants.dart';
part 'forge_scheduler_selection_lease_codec.dart';

/// The explicit request body for a durable scheduler lease claim. The
/// idempotency key is transported in the HTTP header and is intentionally not
/// duplicated in this value.
class ForgeSchedulerSelectionLeaseRequest {
  final String conversationID;
  final String runID;
  final String attemptID;
  final ForgeDevicePlacementRequirements requirements;
  final int ttlMS;

  const ForgeSchedulerSelectionLeaseRequest({
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.requirements,
    required this.ttlMS,
  });

  factory ForgeSchedulerSelectionLeaseRequest.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'conversation_id',
      'run_id',
      'attempt_id',
      'requirements',
      'ttl_ms',
    });
    final ttl = _leaseBoundedInt(json['ttl_ms'], 600000);
    if (ttl < 1000) {
      throw const FormatException('Invalid Forge scheduler lease duration.');
    }
    return ForgeSchedulerSelectionLeaseRequest(
      conversationID: _leaseIdentifier(json['conversation_id']),
      runID: _leaseIdentifier(json['run_id']),
      attemptID: _leaseIdentifier(json['attempt_id']),
      requirements: ForgeDevicePlacementRequirements.fromJson(
        json['requirements'],
      ),
      ttlMS: ttl,
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'requirements': requirements.toJson(),
    'ttl_ms': ttlMS,
  };
}

/// The explicit proof packet for renewing one current scheduler lease. The
/// fencing token is required by the transport but is never rendered by the
/// Sessions UI.
class ForgeSchedulerSelectionLeaseRenewalRequest {
  final String conversationID;
  final String runID;
  final String attemptID;
  final String targetID;
  final int epoch;
  final String fencingToken;
  final int ttlMS;

  const ForgeSchedulerSelectionLeaseRenewalRequest({
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
    required this.ttlMS,
  });

  factory ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'conversation_id',
      'run_id',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
      'ttl_ms',
    });
    final epoch = _leasePositiveInt(json['epoch']);
    final ttl = _leaseBoundedInt(json['ttl_ms'], 600000);
    if (ttl < 1000) {
      throw const FormatException(
        'Invalid Forge scheduler lease renewal duration.',
      );
    }
    return ForgeSchedulerSelectionLeaseRenewalRequest(
      conversationID: _leaseIdentifier(json['conversation_id']),
      runID: _leaseIdentifier(json['run_id']),
      attemptID: _leaseIdentifier(json['attempt_id']),
      targetID: _leaseIdentifier(json['target_id']),
      epoch: epoch,
      fencingToken: _leaseIdentifier(json['fencing_token'], maxLength: 256),
      ttlMS: ttl,
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': epoch,
    'fencing_token': fencingToken,
    'ttl_ms': ttlMS,
  };
}

/// The explicit proof packet for releasing one current scheduler lease. The
/// fencing token is required by the transport and is never rendered by the
/// Sessions UI.
class ForgeSchedulerSelectionLeaseReleaseRequest {
  final String conversationID;
  final String runID;
  final String attemptID;
  final String targetID;
  final int epoch;
  final String fencingToken;

  const ForgeSchedulerSelectionLeaseReleaseRequest({
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
  });

  factory ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'conversation_id',
      'run_id',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
    });
    return ForgeSchedulerSelectionLeaseReleaseRequest(
      conversationID: _leaseIdentifier(json['conversation_id']),
      runID: _leaseIdentifier(json['run_id']),
      attemptID: _leaseIdentifier(json['attempt_id']),
      targetID: _leaseIdentifier(json['target_id']),
      epoch: _leasePositiveInt(json['epoch']),
      fencingToken: _leaseIdentifier(json['fencing_token'], maxLength: 256),
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': epoch,
    'fencing_token': fencingToken,
  };
}

class ForgeSchedulerSelectionLeaseAuthority {
  final bool placementSelected;
  final bool reservationCreated;
  final bool leaseIssued;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeSchedulerSelectionLeaseAuthority({
    required this.placementSelected,
    required this.reservationCreated,
    required this.leaseIssued,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeSchedulerSelectionLeaseAuthority.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'placement_selected',
      'reservation_created',
      'lease_issued',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeSchedulerSelectionLeaseAuthority(
      placementSelected: _leaseBool(json['placement_selected']),
      reservationCreated: _leaseBool(json['reservation_created']),
      leaseIssued: _leaseBool(json['lease_issued']),
      executionAuthorized: _leaseBool(json['execution_authorized']),
      dispatchPerformed: _leaseBool(json['dispatch_performed']),
      auditPublished: _leaseBool(json['audit_published']),
    );
    if (!authority.placementSelected ||
        !authority.reservationCreated ||
        !authority.leaseIssued ||
        authority.executionAuthorized ||
        authority.dispatchPerformed ||
        authority.auditPublished) {
      throw const FormatException('Invalid Forge scheduler lease authority.');
    }
    return authority;
  }

  Map<String, dynamic> toJson() => {
    'placement_selected': placementSelected,
    'reservation_created': reservationCreated,
    'lease_issued': leaseIssued,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeSchedulerSelectionLeaseReleaseAuthority {
  final bool placementSelected;
  final bool reservationCreated;
  final bool leaseIssued;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeSchedulerSelectionLeaseReleaseAuthority({
    required this.placementSelected,
    required this.reservationCreated,
    required this.leaseIssued,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeSchedulerSelectionLeaseReleaseAuthority.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'placement_selected',
      'reservation_created',
      'lease_issued',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeSchedulerSelectionLeaseReleaseAuthority(
      placementSelected: _leaseBool(json['placement_selected']),
      reservationCreated: _leaseBool(json['reservation_created']),
      leaseIssued: _leaseBool(json['lease_issued']),
      executionAuthorized: _leaseBool(json['execution_authorized']),
      dispatchPerformed: _leaseBool(json['dispatch_performed']),
      auditPublished: _leaseBool(json['audit_published']),
    );
    if (authority.placementSelected ||
        authority.reservationCreated ||
        authority.leaseIssued ||
        authority.executionAuthorized ||
        authority.dispatchPerformed ||
        authority.auditPublished) {
      throw const FormatException(
        'Invalid Forge scheduler lease release authority.',
      );
    }
    return authority;
  }

  Map<String, dynamic> toJson() => {
    'placement_selected': placementSelected,
    'reservation_created': reservationCreated,
    'lease_issued': leaseIssued,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}
