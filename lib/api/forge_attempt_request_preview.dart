import 'dart:convert';

part 'forge_attempt_request_preview_validation.dart';

/// Offline, display-only consumer for the shared Forge Attempt request
/// contract. It deliberately does not resolve references or make a request.
const forgeAttemptRequestSchema = 'forge.attempt-request/v1';
const forgeAttemptRequestEvaluationMode = 'pure_attempt_request_only';
const forgeAttemptRequestMaxCases = 64;

class ForgeAttemptRequestAuthority {
  final bool deviceIdentityVerified;
  final bool referencesResolved;
  final bool requestPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeAttemptRequestAuthority({
    required this.deviceIdentityVerified,
    required this.referencesResolved,
    required this.requestPersisted,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  bool get isOffline =>
      !deviceIdentityVerified &&
      !referencesResolved &&
      !requestPersisted &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  factory ForgeAttemptRequestAuthority.fromJson(Object? value) {
    final json = _attemptRequestObject(value, 'authority');
    _attemptRequestExactKeys(json, {
      'device_identity_verified',
      'references_resolved',
      'request_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeAttemptRequestAuthority(
      deviceIdentityVerified: _attemptRequestBool(
        json['device_identity_verified'],
      ),
      referencesResolved: _attemptRequestBool(json['references_resolved']),
      requestPersisted: _attemptRequestBool(json['request_persisted']),
      reservationCreated: _attemptRequestBool(json['reservation_created']),
      executionAuthorized: _attemptRequestBool(json['execution_authorized']),
      dispatchPerformed: _attemptRequestBool(json['dispatch_performed']),
      auditPublished: _attemptRequestBool(json['audit_published']),
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Forge Attempt request authority must remain false.',
      );
    }
    return authority;
  }

  Map<String, dynamic> toJson() => {
    'device_identity_verified': deviceIdentityVerified,
    'references_resolved': referencesResolved,
    'request_persisted': requestPersisted,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeAttemptRequestPreviewCase {
  final String name;
  final bool accepted;
  final String error;
  final String initialState;
  final List<String> requestedEffects;
  final List<String> approvalRecordIDs;

  const ForgeAttemptRequestPreviewCase({
    required this.name,
    required this.accepted,
    required this.error,
    required this.initialState,
    required this.requestedEffects,
    required this.approvalRecordIDs,
  });

  factory ForgeAttemptRequestPreviewCase.fromJson(Object? value) {
    final json = _attemptRequestObject(value, 'case');
    _attemptRequestExactKeys(json, {'name', 'request', 'expected'});
    final request = _attemptRequestObject(json['request'], 'request');
    _validateRequest(request);
    final expected = _attemptRequestObject(json['expected'], 'expected');
    _attemptRequestExactKeys(expected, {
      'accepted',
      'error',
      'initial_state',
      'requested_effects',
      'approval_record_ids',
    });
    final accepted = _attemptRequestBool(expected['accepted']);
    final error = _attemptRequestError(expected['error']);
    if (accepted && error.isNotEmpty || !accepted && error.isEmpty) {
      throw const FormatException(
        'Forge Attempt request expected error is inconsistent.',
      );
    }
    if (!accepted &&
        error != 'invalid_value' &&
        error != 'reference_mismatch') {
      throw const FormatException('Unknown Forge Attempt request error.');
    }
    final initialState = _attemptRequestText(
      expected['initial_state'],
      'initial_state',
    );
    if (initialState != 'requested') {
      throw const FormatException(
        'Forge Attempt request initial state must be requested.',
      );
    }
    final requestedEffects = _attemptRequestTextList(
      expected['requested_effects'],
      'requested_effects',
      allowEmpty: true,
      sortAndRequireUnique: true,
    );
    final approvals = _attemptRequestTextList(
      expected['approval_record_ids'],
      'approval_record_ids',
      allowEmpty: true,
      sortAndRequireUnique: true,
    );
    if (accepted) {
      final normalizedEffects = _normalizedRequestEffects(
        request['requested_effects'],
      );
      final normalizedApprovals = _normalizedRequestApprovalIDs(
        request['approval_refs'],
      );
      if (normalizedEffects.join('\u0000') != requestedEffects.join('\u0000') ||
          normalizedApprovals.join('\u0000') != approvals.join('\u0000')) {
        throw const FormatException(
          'Forge Attempt request expected normalization drifted.',
        );
      }
    }
    return ForgeAttemptRequestPreviewCase(
      name: _attemptRequestText(json['name'], 'name'),
      accepted: accepted,
      error: error,
      initialState: initialState,
      requestedEffects: List.unmodifiable(requestedEffects),
      approvalRecordIDs: List.unmodifiable(approvals),
    );
  }
}

List<String> _normalizedRequestEffects(Object? value) {
  final effects = _attemptRequestTextList(
    value,
    'request.requested_effects',
    allowEmpty: true,
    sortAndRequireUnique: false,
  );
  return [...effects]..sort();
}

List<String> _normalizedRequestApprovalIDs(Object? value) {
  if (value is! List || value.length > 16) {
    throw const FormatException('Invalid Forge Attempt request approvals.');
  }
  final ids = <String>[];
  for (final raw in value) {
    final record = _validateRecord(raw);
    ids.add(record);
  }
  return [...ids]..sort();
}

class ForgeAttemptRequestPreviewFixture {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeAttemptRequestAuthority authority;
  final List<ForgeAttemptRequestPreviewCase> cases;

  const ForgeAttemptRequestPreviewFixture({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.authority,
    required this.cases,
  });

  factory ForgeAttemptRequestPreviewFixture.fromJson(Object? value) {
    final json = _attemptRequestObject(value, 'fixture');
    _attemptRequestExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'authority',
      'cases',
    });
    if (json['schema_version'] != forgeAttemptRequestSchema ||
        json['evaluation_mode'] != forgeAttemptRequestEvaluationMode) {
      throw const FormatException(
        'Invalid Forge Attempt request contract envelope.',
      );
    }
    final rawCases = json['cases'];
    if (rawCases is! List ||
        rawCases.isEmpty ||
        rawCases.length > forgeAttemptRequestMaxCases) {
      throw const FormatException(
        'Forge Attempt request fixture must contain 1..64 cases.',
      );
    }
    final names = <String>{};
    final cases = <ForgeAttemptRequestPreviewCase>[];
    for (final rawCase in rawCases) {
      final parsed = ForgeAttemptRequestPreviewCase.fromJson(rawCase);
      if (!names.add(parsed.name)) {
        throw const FormatException(
          'Duplicate Forge Attempt request case name.',
        );
      }
      cases.add(parsed);
    }
    return ForgeAttemptRequestPreviewFixture(
      schemaVersion: forgeAttemptRequestSchema,
      evaluationMode: forgeAttemptRequestEvaluationMode,
      authority: ForgeAttemptRequestAuthority.fromJson(json['authority']),
      cases: List.unmodifiable(cases),
    );
  }

  /// Decode a bounded raw JSON document while retaining duplicate-key safety.
  factory ForgeAttemptRequestPreviewFixture.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Forge Attempt request fixture is too large.',
      );
    }
    _rejectAttemptRequestDuplicateKeys(source);
    return ForgeAttemptRequestPreviewFixture.fromJson(
      _decodeAttemptRequestJson(source),
    );
  }
}
