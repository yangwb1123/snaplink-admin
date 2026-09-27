import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_device_placement.dart';

/// The planning-only scheduler-selection request. It is an owner-bound value
/// declaration; the owner itself is taken from the authenticated principal by
/// the server and is therefore intentionally absent here.
class ForgeSchedulerSelectionPreviewRequest {
  final String conversationID;
  final String runID;
  final String attemptID;
  final ForgeDevicePlacementRequirements requirements;

  const ForgeSchedulerSelectionPreviewRequest({
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.requirements,
  });

  factory ForgeSchedulerSelectionPreviewRequest.fromJson(Object? value) {
    final json = _schedulerObject(value);
    _schedulerExactKeys(json, {
      'conversation_id',
      'run_id',
      'attempt_id',
      'requirements',
    });
    return ForgeSchedulerSelectionPreviewRequest(
      conversationID: _schedulerIdentifier(json['conversation_id']),
      runID: _schedulerIdentifier(json['run_id']),
      attemptID: _schedulerIdentifier(json['attempt_id']),
      requirements: ForgeDevicePlacementRequirements.fromJson(
        json['requirements'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'requirements': requirements.toJson(),
  };

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;
}

class ForgeSchedulerSelectionAuthority {
  final bool placementSelected;
  final bool reservationCreated;
  final bool leaseIssued;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeSchedulerSelectionAuthority({
    required this.placementSelected,
    required this.reservationCreated,
    required this.leaseIssued,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  bool get anyGranted =>
      placementSelected ||
      reservationCreated ||
      leaseIssued ||
      executionAuthorized ||
      dispatchPerformed ||
      auditPublished;

  factory ForgeSchedulerSelectionAuthority.fromJson(Object? value) {
    final json = _schedulerObject(value);
    _schedulerExactKeys(json, {
      'placement_selected',
      'reservation_created',
      'lease_issued',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeSchedulerSelectionAuthority(
      placementSelected: _schedulerBool(json['placement_selected']),
      reservationCreated: _schedulerBool(json['reservation_created']),
      leaseIssued: _schedulerBool(json['lease_issued']),
      executionAuthorized: _schedulerBool(json['execution_authorized']),
      dispatchPerformed: _schedulerBool(json['dispatch_performed']),
      auditPublished: _schedulerBool(json['audit_published']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge scheduler selection preview grants authority.',
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

/// Strict response projection for `forge.scheduler-selection-preview/v1`.
/// `selected*` values explain a deterministic preview only. They never grant
/// a lease, reserve capacity, or authorize a Runner.
class ForgeSchedulerSelectionPreview {
  static const schema = 'forge.scheduler-selection-preview/v1';
  static const evaluationMode = 'pure_scheduler_selection_preview';
  static const maxCandidates = 128;
  static const maxSafeInteger = 9007199254740991;

  final String schemaVersion;
  final String mode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final int evaluatedAtMS;
  final int candidateCount;
  final int eligibleCandidateCount;
  final bool selectionAvailable;
  final String selectionReason;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final bool previewOnly;
  final ForgeSchedulerSelectionAuthority authority;

  const ForgeSchedulerSelectionPreview({
    required this.schemaVersion,
    required this.mode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.evaluatedAtMS,
    required this.candidateCount,
    required this.eligibleCandidateCount,
    required this.selectionAvailable,
    required this.selectionReason,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.previewOnly,
    required this.authority,
  });

  factory ForgeSchedulerSelectionPreview.fromJsonText(String source) {
    if (utf8.encode(source).length > 512 * 1024) {
      throw const FormatException(
        'Forge scheduler selection preview is too large.',
      );
    }
    _SchedulerDuplicateScanner(source).scan();
    return ForgeSchedulerSelectionPreview.fromJson(jsonDecode(source));
  }

  factory ForgeSchedulerSelectionPreview.fromJson(Object? value) {
    final json = _schedulerObject(value);
    _schedulerExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'evaluated_at_ms',
      'candidate_count',
      'eligible_candidate_count',
      'selection_available',
      'selection_reason',
      'selected_device_id',
      'selected_instance_id',
      'preview_only',
      'authority',
    });
    if (json['schema_version'] != schema ||
        json['evaluation_mode'] != evaluationMode) {
      throw const FormatException(
        'Invalid Forge scheduler selection preview envelope.',
      );
    }
    final available = json['selection_available'];
    final previewOnly = json['preview_only'];
    if (available is! bool || previewOnly is! bool || !previewOnly) {
      throw const FormatException(
        'Invalid Forge scheduler selection preview flags.',
      );
    }
    final candidateCount = _schedulerBoundedInt(
      json['candidate_count'],
      maxCandidates,
    );
    final eligibleCount = _schedulerBoundedInt(
      json['eligible_candidate_count'],
      maxCandidates,
    );
    if (eligibleCount > candidateCount) {
      throw const FormatException(
        'Forge scheduler selection eligible count exceeds candidates.',
      );
    }
    final selectedDevice = _schedulerNullableIdentifier(
      json['selected_device_id'],
    );
    final selectedInstance = _schedulerNullableIdentifier(
      json['selected_instance_id'],
    );
    final reason = _schedulerIdentifier(json['selection_reason']);
    if (available) {
      if (eligibleCount == 0 ||
          selectedDevice == null ||
          selectedInstance == null ||
          reason != 'first_sorted_eligible_candidate') {
        throw const FormatException(
          'Forge scheduler selection preview has an invalid selection.',
        );
      }
    } else if (selectedDevice != null ||
        selectedInstance != null ||
        reason != 'no_eligible_candidate') {
      throw const FormatException(
        'Forge scheduler selection preview has an invalid empty selection.',
      );
    }
    return ForgeSchedulerSelectionPreview(
      schemaVersion: schema,
      mode: evaluationMode,
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _schedulerIdentifier(json['conversation_id']),
      runID: _schedulerIdentifier(json['run_id']),
      attemptID: _schedulerIdentifier(json['attempt_id']),
      evaluatedAtMS: _schedulerPositiveInt(json['evaluated_at_ms']),
      candidateCount: candidateCount,
      eligibleCandidateCount: eligibleCount,
      selectionAvailable: available,
      selectionReason: reason,
      selectedDeviceID: selectedDevice,
      selectedInstanceID: selectedInstance,
      previewOnly: true,
      authority: ForgeSchedulerSelectionAuthority.fromJson(json['authority']),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': mode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'evaluated_at_ms': evaluatedAtMS,
    'candidate_count': candidateCount,
    'eligible_candidate_count': eligibleCandidateCount,
    'selection_available': selectionAvailable,
    'selection_reason': selectionReason,
    'selected_device_id': selectedDeviceID,
    'selected_instance_id': selectedInstanceID,
    'preview_only': previewOnly,
    'authority': authority.toJson(),
  };

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;
}

Map<String, dynamic> _schedulerObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid Forge scheduler selection object.');
  }
  return Map<String, dynamic>.from(value);
}

void _schedulerExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge scheduler selection fields.');
  }
}

bool _schedulerBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge scheduler selection boolean.');
  }
  return value;
}

int _schedulerPositiveInt(Object? value) {
  final parsed = _schedulerBoundedInt(
    value,
    ForgeSchedulerSelectionPreview.maxSafeInteger,
  );
  if (parsed <= 0) {
    throw const FormatException('Invalid Forge scheduler selection timestamp.');
  }
  return parsed;
}

int _schedulerBoundedInt(Object? value, int maximum) {
  if (value is! int || value < 0 || value > maximum) {
    throw const FormatException('Invalid Forge scheduler selection integer.');
  }
  return value;
}

String _schedulerIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_schedulerIdentifierCodeUnits(value)) {
    throw const FormatException(
      'Invalid Forge scheduler selection identifier.',
    );
  }
  return value;
}

String? _schedulerNullableIdentifier(Object? value) =>
    value == null ? null : _schedulerIdentifier(value);

bool _schedulerIdentifierCodeUnits(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) ||
      code == 0x2e ||
      code == 0x5f ||
      code == 0x3a ||
      code == 0x2b ||
      code == 0x2f ||
      code == 0x2d;
  final codes = value.codeUnits;
  return codes.isNotEmpty && first(codes.first) && codes.skip(1).every(rest);
}

/// Bounded duplicate-key scanner. `jsonDecode` otherwise keeps the last
/// occurrence, which would make an authority mutation indistinguishable from
/// a valid response.
class _SchedulerDuplicateScanner {
  final String source;
  final List<Set<String>> _objects = <Set<String>>[];

  _SchedulerDuplicateScanner(this.source);

  void scan() {
    var inString = false;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        final start = index;
        index++;
        var stringEscaped = false;
        for (; index < source.length; index++) {
          final current = source[index];
          if (stringEscaped) {
            stringEscaped = false;
          } else if (current == r'\') {
            stringEscaped = true;
          } else if (current == '"') {
            break;
          }
        }
        final end = index + 1;
        var next = end;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (_objects.isEmpty) {
            throw const FormatException('Forge scheduler key outside object.');
          }
          final key = jsonDecode(source.substring(start, end)) as String;
          if (!_objects.last.add(key)) {
            throw const FormatException(
              'Duplicate Forge scheduler selection key.',
            );
          }
        }
        inString = false;
        continue;
      }
      if (char == '{') _objects.add(<String>{});
      if (char == '}') {
        if (_objects.isEmpty) {
          throw const FormatException('Unbalanced Forge scheduler object.');
        }
        _objects.removeLast();
      }
    }
    if (inString || _objects.isNotEmpty) {
      throw const FormatException('Unbalanced Forge scheduler JSON.');
    }
  }
}
