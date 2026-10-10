part of 'forge_device_credential_candidate.dart';

class ForgeDeviceCredentialLifecycleCandidate {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String deviceID;
  final String action;
  final int revision;
  final ForgeDeviceCredentialLifecycleState? previous;
  final ForgeDeviceCredentialLifecycleState next;
  final bool previewOnly;
  final bool candidatePublished;
  final ForgeDeviceCredentialLifecycleAuthority authority;

  const ForgeDeviceCredentialLifecycleCandidate({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.deviceID,
    required this.action,
    required this.revision,
    required this.previous,
    required this.next,
    required this.previewOnly,
    required this.candidatePublished,
    required this.authority,
  });

  factory ForgeDeviceCredentialLifecycleCandidate.fromJson(Object? value) {
    final json = _credentialCandidateObject(value, 'response');
    final expectedKeys = {
      'schema_version',
      'evaluation_mode',
      'owner',
      'device_id',
      'action',
      'revision',
      'next',
      'preview_only',
      'candidate_published',
      'authority',
    };
    if (json.containsKey('previous')) expectedKeys.add('previous');
    _credentialCandidateExactKeys(json, expectedKeys);
    if (json['schema_version'] != forgeDeviceCredentialCandidateSchema ||
        json['evaluation_mode'] !=
            forgeDeviceCredentialCandidateEvaluationMode) {
      throw const FormatException(
        'Invalid Forge credential candidate envelope.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['owner']);
    final deviceID = _credentialCandidateIdentifier(
      json['device_id'],
      'device ID',
    );
    final action = _credentialCandidateOneOf(json['action'], {
      'issue',
      'revoke',
      'rotate',
    }, 'action');
    final next = ForgeDeviceCredentialLifecycleState.fromJson(json['next']);
    final previous = json.containsKey('previous') && json['previous'] != null
        ? ForgeDeviceCredentialLifecycleState.fromJson(json['previous'])
        : null;
    final previewOnly = _credentialCandidateBool(
      json['preview_only'],
      'preview_only',
    );
    final candidatePublished = _credentialCandidateBool(
      json['candidate_published'],
      'candidate_published',
    );
    final candidate = ForgeDeviceCredentialLifecycleCandidate(
      schemaVersion: forgeDeviceCredentialCandidateSchema,
      evaluationMode: forgeDeviceCredentialCandidateEvaluationMode,
      owner: owner,
      deviceID: deviceID,
      action: action,
      revision: _credentialCandidatePositiveSafeInteger(
        json['revision'],
        'revision',
      ),
      previous: previous,
      next: next,
      previewOnly: previewOnly,
      candidatePublished: candidatePublished,
      authority: ForgeDeviceCredentialLifecycleAuthority.fromJson(
        json['authority'],
      ),
    );
    candidate._validateBindings();
    return candidate;
  }

  factory ForgeDeviceCredentialLifecycleCandidate.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException('Forge credential candidate is too large.');
    }
    _credentialCandidateRejectDuplicateKeys(source);
    try {
      return ForgeDeviceCredentialLifecycleCandidate.fromJson(
        jsonDecode(source),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid Forge credential candidate JSON.');
    }
  }

  /// Binds a decoded value to the caller's owner declaration. This pure
  /// helper performs no HTTP request, token refresh, or authority transition.
  static ForgeDeviceCredentialLifecycleCandidate decodeForOwner(
    Object? value, {
    required ForgeDeviceOwner owner,
  }) {
    final candidate = ForgeDeviceCredentialLifecycleCandidate.fromJson(value);
    if (candidate.owner != ForgeDeviceOwner.fromJson(owner.toJson())) {
      throw const FormatException(
        'Forge credential candidate belongs to another owner.',
      );
    }
    return candidate;
  }

  bool get isDisplayOnly =>
      previewOnly && candidatePublished && authority.isOffline;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'device_id': deviceID,
    'action': action,
    'revision': revision,
    if (previous != null) 'previous': previous!.toJson(),
    'next': next.toJson(),
    'preview_only': previewOnly,
    'candidate_published': candidatePublished,
    'authority': authority.toJson(),
  };

  void _validateBindings() {
    if (!previewOnly || !candidatePublished || !authority.isOffline) {
      throw const FormatException(
        'Forge credential candidate must remain display-only.',
      );
    }
    if (next.owner != owner || next.deviceID != deviceID) {
      throw const FormatException(
        'Forge credential candidate next state binding changed.',
      );
    }
    switch (action) {
      case 'issue':
        if (previous != null || next.credentialState != 'active') {
          throw const FormatException(
            'Invalid Forge credential issue candidate.',
          );
        }
        break;
      case 'revoke':
        final prior = previous;
        if (prior == null ||
            prior.owner != owner ||
            prior.deviceID != deviceID ||
            next.credentialState != 'revoked' ||
            !_sameCredentialMetadata(prior, next)) {
          throw const FormatException(
            'Invalid Forge credential revoke candidate.',
          );
        }
        break;
      case 'rotate':
        final prior = previous;
        if (prior == null ||
            prior.owner != owner ||
            prior.deviceID != deviceID ||
            next.credentialState != 'active' ||
            next.keyGeneration != prior.keyGeneration + 1 ||
            next.credentialID == prior.credentialID &&
                next.keyID == prior.keyID &&
                next.publicKeySHA256 == prior.publicKeySHA256 ||
            next.approvalState != prior.approvalState) {
          throw const FormatException(
            'Invalid Forge credential rotate candidate.',
          );
        }
        break;
    }
  }
}

bool _sameCredentialMetadata(
  ForgeDeviceCredentialLifecycleState left,
  ForgeDeviceCredentialLifecycleState right,
) =>
    left.credentialID == right.credentialID &&
    left.deviceID == right.deviceID &&
    left.owner == right.owner &&
    left.approvalState == right.approvalState &&
    left.keyID == right.keyID &&
    left.publicKeySHA256 == right.publicKeySHA256 &&
    left.keyGeneration == right.keyGeneration &&
    left.issuedAtMS == right.issuedAtMS &&
    left.expiresAtMS == right.expiresAtMS;
