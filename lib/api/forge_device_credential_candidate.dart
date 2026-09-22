import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

/// Strict metadata-only response from the injected Core credential candidate.
/// The value contains no bearer, private key, or credential secret and cannot
/// be used to authorize a device or execution.
const forgeDeviceCredentialCandidateSchema =
    'forge.device-credential-lifecycle/v1';
const forgeDeviceCredentialCandidateEvaluationMode =
    'pure_device_credential_lifecycle';
const forgeDeviceCredentialCandidateMaxSafeInteger = 9007199254740991;
const forgeDeviceCredentialCandidateMinLifetimeMS = 1000;
const forgeDeviceCredentialCandidateMaxLifetimeMS = 3600000;

/// Caller-supplied metadata for the injected credential lifecycle candidate.
///
/// The owner is deliberately absent from this request: Forge derives it from
/// the authenticated bearer and the response is rebound to the explicit owner
/// supplied to the transport method. Empty replacement/current fields are
/// retained for revoke requests because the Core candidate route accepts the
/// same exact request shape for all three actions.
class ForgeDeviceCredentialLifecycleRequest {
  final String deviceID;
  final String action;
  final String approvalState;
  final String credentialID;
  final String keyID;
  final String publicKeySHA256;
  final int keyGeneration;
  final int issuedAtMS;
  final int expiresAtMS;
  final String nextCredentialID;
  final String nextKeyID;
  final String nextPublicKeySHA256;
  final int observedAtMS;
  final int expectedDeviceRevision;

  const ForgeDeviceCredentialLifecycleRequest({
    required this.deviceID,
    required this.action,
    required this.approvalState,
    required this.credentialID,
    required this.keyID,
    required this.publicKeySHA256,
    required this.keyGeneration,
    required this.issuedAtMS,
    required this.expiresAtMS,
    required this.nextCredentialID,
    required this.nextKeyID,
    required this.nextPublicKeySHA256,
    required this.observedAtMS,
    required this.expectedDeviceRevision,
  });

  factory ForgeDeviceCredentialLifecycleRequest.fromJson(Object? value) {
    final json = _credentialCandidateObject(value, 'request');
    _credentialCandidateExactKeys(json, {
      'device_id',
      'action',
      'approval_state',
      'credential_id',
      'key_id',
      'public_key_sha256',
      'key_generation',
      'issued_at_ms',
      'expires_at_ms',
      'next_credential_id',
      'next_key_id',
      'next_public_key_sha256',
      'observed_at_ms',
      'expected_device_revision',
    });
    final action = _credentialCandidateOneOf(json['action'], {
      'issue',
      'revoke',
      'rotate',
    }, 'action');
    final approvalState = _credentialCandidateOptionalOneOf(
      json['approval_state'],
      {'pending', 'approved', 'revoked'},
      'approval state',
    );
    final request = ForgeDeviceCredentialLifecycleRequest(
      deviceID: _credentialCandidateIdentifier(json['device_id'], 'device ID'),
      action: action,
      approvalState: approvalState,
      credentialID: _credentialCandidateOptionalIdentifier(
        json['credential_id'],
        'credential ID',
      ),
      keyID: _credentialCandidateOptionalIdentifier(json['key_id'], 'key ID'),
      publicKeySHA256: _credentialCandidateOptionalDigest(
        json['public_key_sha256'],
        'public key digest',
      ),
      keyGeneration: _credentialCandidateSafeInteger(
        json['key_generation'],
        'key generation',
      ),
      issuedAtMS: _credentialCandidateSafeInteger(
        json['issued_at_ms'],
        'issued time',
      ),
      expiresAtMS: _credentialCandidateSafeInteger(
        json['expires_at_ms'],
        'expiry time',
      ),
      nextCredentialID: _credentialCandidateOptionalIdentifier(
        json['next_credential_id'],
        'next credential ID',
      ),
      nextKeyID: _credentialCandidateOptionalIdentifier(
        json['next_key_id'],
        'next key ID',
      ),
      nextPublicKeySHA256: _credentialCandidateOptionalDigest(
        json['next_public_key_sha256'],
        'next public key digest',
      ),
      observedAtMS: _credentialCandidateSafeInteger(
        json['observed_at_ms'],
        'observation time',
      ),
      expectedDeviceRevision: _credentialCandidatePositiveSafeInteger(
        json['expected_device_revision'],
        'expected device revision',
      ),
    );
    request._validateActionInputs();
    return request;
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceID,
    'action': action,
    'approval_state': approvalState,
    'credential_id': credentialID,
    'key_id': keyID,
    'public_key_sha256': publicKeySHA256,
    'key_generation': keyGeneration,
    'issued_at_ms': issuedAtMS,
    'expires_at_ms': expiresAtMS,
    'next_credential_id': nextCredentialID,
    'next_key_id': nextKeyID,
    'next_public_key_sha256': nextPublicKeySHA256,
    'observed_at_ms': observedAtMS,
    'expected_device_revision': expectedDeviceRevision,
  };

  void _validateActionInputs() {
    switch (action) {
      case 'issue':
        if (approvalState == '' || approvalState == 'revoked') {
          throw const FormatException(
            'Forge credential issue requires non-revoked approval.',
          );
        }
        _requireIdentifier(credentialID, 'credential ID');
        _requireKey(keyID, publicKeySHA256, keyGeneration);
        _validateWindow(issuedAtMS, expiresAtMS, observedAtMS);
        break;
      case 'rotate':
        _requireIdentifier(nextCredentialID, 'next credential ID');
        _requireKey(nextKeyID, nextPublicKeySHA256, 1);
        _validateWindow(issuedAtMS, expiresAtMS, observedAtMS);
        break;
      case 'revoke':
        // Core binds revoke to the persisted candidate; omitted current
        // metadata is valid and keeps the request body deterministic.
        break;
    }
  }

  void _requireIdentifier(String value, String label) {
    if (value.isEmpty) {
      throw FormatException('Forge credential request requires $label.');
    }
  }

  void _requireKey(String keyID, String digest, int generation) {
    if (keyID.isEmpty || digest.isEmpty || generation == 0) {
      throw const FormatException(
        'Forge credential request requires complete key metadata.',
      );
    }
  }

  void _validateWindow(int issued, int expires, int observed) {
    if (expires <= issued ||
        expires - issued < forgeDeviceCredentialCandidateMinLifetimeMS ||
        expires - issued > forgeDeviceCredentialCandidateMaxLifetimeMS ||
        observed < issued ||
        observed >= expires) {
      throw const FormatException('Invalid Forge credential request window.');
    }
  }
}

class ForgeDeviceCredentialLifecycleAuthority {
  final bool ownerBindingMatched;
  final bool ownerAuthenticated;
  final bool credentialMaterialMade;
  final bool persisted;
  final bool inventoryAuthoritative;
  final bool executionAuthorized;

  const ForgeDeviceCredentialLifecycleAuthority.offline()
    : ownerBindingMatched = false,
      ownerAuthenticated = false,
      credentialMaterialMade = false,
      persisted = false,
      inventoryAuthoritative = false,
      executionAuthorized = false;

  factory ForgeDeviceCredentialLifecycleAuthority.fromJson(Object? value) {
    final json = _credentialCandidateObject(value, 'authority');
    _credentialCandidateExactKeys(json, {
      'owner_binding_matched',
      'owner_authenticated',
      'credential_material_made',
      'persisted',
      'inventory_authoritative',
      'execution_authorized',
    });
    for (final entry in json.entries) {
      if (entry.value is! bool || entry.value == true) {
        throw const FormatException(
          'Forge credential candidate authority must remain false.',
        );
      }
    }
    return const ForgeDeviceCredentialLifecycleAuthority.offline();
  }

  bool get isOffline =>
      !ownerBindingMatched &&
      !ownerAuthenticated &&
      !credentialMaterialMade &&
      !persisted &&
      !inventoryAuthoritative &&
      !executionAuthorized;

  Map<String, dynamic> toJson() => {
    'owner_binding_matched': ownerBindingMatched,
    'owner_authenticated': ownerAuthenticated,
    'credential_material_made': credentialMaterialMade,
    'persisted': persisted,
    'inventory_authoritative': inventoryAuthoritative,
    'execution_authorized': executionAuthorized,
  };
}

class ForgeDeviceCredentialLifecycleState {
  final String credentialID;
  final String deviceID;
  final ForgeDeviceOwner owner;
  final String approvalState;
  final String credentialState;
  final String keyID;
  final String publicKeySHA256;
  final int keyGeneration;
  final int issuedAtMS;
  final int expiresAtMS;

  const ForgeDeviceCredentialLifecycleState({
    required this.credentialID,
    required this.deviceID,
    required this.owner,
    required this.approvalState,
    required this.credentialState,
    required this.keyID,
    required this.publicKeySHA256,
    required this.keyGeneration,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory ForgeDeviceCredentialLifecycleState.fromJson(Object? value) {
    final json = _credentialCandidateObject(value, 'state');
    _credentialCandidateExactKeys(json, {
      'credential_id',
      'device_id',
      'owner',
      'approval_state',
      'credential_state',
      'key_id',
      'public_key_sha256',
      'key_generation',
      'issued_at_ms',
      'expires_at_ms',
    });
    final state = ForgeDeviceCredentialLifecycleState(
      credentialID: _credentialCandidateIdentifier(
        json['credential_id'],
        'credential ID',
      ),
      deviceID: _credentialCandidateIdentifier(json['device_id'], 'device ID'),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      approvalState: _credentialCandidateOneOf(json['approval_state'], {
        'pending',
        'approved',
        'revoked',
      }, 'approval state'),
      credentialState: _credentialCandidateOneOf(json['credential_state'], {
        'active',
        'expired',
        'revoked',
      }, 'credential state'),
      keyID: _credentialCandidateIdentifier(json['key_id'], 'key ID'),
      publicKeySHA256: _credentialCandidateDigest(
        json['public_key_sha256'],
        'public key digest',
      ),
      keyGeneration: _credentialCandidatePositiveSafeInteger(
        json['key_generation'],
        'key generation',
      ),
      issuedAtMS: _credentialCandidateSafeInteger(
        json['issued_at_ms'],
        'issued time',
      ),
      expiresAtMS: _credentialCandidateSafeInteger(
        json['expires_at_ms'],
        'expiry time',
      ),
    );
    if (state.expiresAtMS <= state.issuedAtMS ||
        state.expiresAtMS - state.issuedAtMS <
            forgeDeviceCredentialCandidateMinLifetimeMS ||
        state.expiresAtMS - state.issuedAtMS >
            forgeDeviceCredentialCandidateMaxLifetimeMS) {
      throw const FormatException('Invalid Forge credential candidate window.');
    }
    return state;
  }

  Map<String, dynamic> toJson() => {
    'credential_id': credentialID,
    'device_id': deviceID,
    'owner': owner.toJson(),
    'approval_state': approvalState,
    'credential_state': credentialState,
    'key_id': keyID,
    'public_key_sha256': publicKeySHA256,
    'key_generation': keyGeneration,
    'issued_at_ms': issuedAtMS,
    'expires_at_ms': expiresAtMS,
  };
}

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

Map<String, dynamic> _credentialCandidateObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Forge credential candidate $label must be an object.',
    );
  }
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw FormatException(
      'Forge credential candidate $label has invalid keys.',
    );
  }
}

void _credentialCandidateExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge credential candidate fields.',
    );
  }
}

String _credentialCandidateIdentifier(Object? value, String label) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_credentialCandidateASCIIIdentifier(value)) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

bool _credentialCandidateASCIIIdentifier(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) || const [0x2e, 0x5f, 0x3a, 0x2d].contains(code);
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

String _credentialCandidateOneOf(
  Object? value,
  Set<String> allowed,
  String label,
) {
  if (value is! String || !allowed.contains(value)) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

String _credentialCandidateOptionalOneOf(
  Object? value,
  Set<String> allowed,
  String label,
) {
  if (value is! String || (value.isNotEmpty && !allowed.contains(value))) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

String _credentialCandidateOptionalIdentifier(Object? value, String label) {
  if (value is! String) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value.isEmpty ? value : _credentialCandidateIdentifier(value, label);
}

String _credentialCandidateDigest(Object? value, String label) {
  if (value is! String ||
      value.length != 64 ||
      value.runes.any(
        (rune) =>
            !(rune >= 0x30 && rune <= 0x39 || rune >= 0x61 && rune <= 0x66),
      )) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

String _credentialCandidateOptionalDigest(Object? value, String label) {
  if (value is! String) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value.isEmpty ? value : _credentialCandidateDigest(value, label);
}

int _credentialCandidateSafeInteger(Object? value, String label) {
  if (value is! int ||
      value < 0 ||
      value > forgeDeviceCredentialCandidateMaxSafeInteger) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

int _credentialCandidatePositiveSafeInteger(Object? value, String label) {
  final number = _credentialCandidateSafeInteger(value, label);
  if (number == 0) {
    throw FormatException(
      'Forge credential candidate $label must be positive.',
    );
  }
  return number;
}

bool _credentialCandidateBool(Object? value, String label) {
  if (value is! bool) {
    throw FormatException('Invalid Forge credential candidate $label.');
  }
  return value;
}

void _credentialCandidateRejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character == '\\') {
        escaped = true;
      } else if (character == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Forge credential candidate contains duplicate JSON fields.',
            );
          }
        }
      }
      continue;
    }
    if (character == '"') {
      inString = true;
      stringStart = index;
    } else if (character == '{') {
      objects.add(<String>{});
    } else if (character == '}') {
      if (objects.isEmpty) {
        throw const FormatException('Invalid Forge credential candidate JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge credential candidate JSON.');
  }
}
