import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

part 'forge_device_credential_candidate_observation.dart';
part 'forge_device_credential_candidate_codec.dart';

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
