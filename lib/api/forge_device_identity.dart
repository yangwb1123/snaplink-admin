import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

const forgeDeviceIdentityProofSchema =
    'forge.device-identity-proof-contract/v1';
const forgeDeviceIdentityProofEvaluationMode = 'pure_binding_only';
const forgeDeviceIdentityProofDigestLength = 64;
const forgeDeviceIdentityProofNotice =
    'This fixture checks exact device-owner-key and one-time challenge binding only. The proof digest is a test-vector label; no cryptographic verifier, credential issuer, persistence, network, approval write, inventory authority, or execution authority is present.';
final _identityMaxUint64 = (BigInt.one << 64) - BigInt.one;
const _identityMaxUint64Literal = '18446744073709551615';
const _identityMaxUint64Marker = '__forge_u64_max__';

class ForgeDeviceIdentityBinding {
  final String deviceID;
  final ForgeDeviceOwner owner;
  final String keyID;
  final String publicKeySHA256;
  final String approvalState;
  final String credentialState;

  const ForgeDeviceIdentityBinding({
    required this.deviceID,
    required this.owner,
    required this.keyID,
    required this.publicKeySHA256,
    required this.approvalState,
    required this.credentialState,
  });

  factory ForgeDeviceIdentityBinding.fromJson(Object? value) {
    final json = _object(value, 'identity device');
    _exactKeys(json, {
      'device_id',
      'owner',
      'key_id',
      'public_key_sha256',
      'approval_state',
      'credential_state',
    });
    return ForgeDeviceIdentityBinding(
      deviceID: _text(json['device_id']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      keyID: _text(json['key_id']),
      publicKeySHA256: _text(json['public_key_sha256']),
      approvalState: _text(json['approval_state']),
      credentialState: _text(json['credential_state']),
    );
  }
}

class ForgeDeviceIdentityChallenge {
  final String challengeID;
  final String challengeSHA256;
  final BigInt issuedAtMS;
  final BigInt expiresAtMS;
  final bool consumed;

  const ForgeDeviceIdentityChallenge({
    required this.challengeID,
    required this.challengeSHA256,
    required this.issuedAtMS,
    required this.expiresAtMS,
    required this.consumed,
  });

  factory ForgeDeviceIdentityChallenge.fromJson(Object? value) {
    final json = _object(value, 'identity challenge');
    _exactKeys(json, {
      'challenge_id',
      'challenge_sha256',
      'issued_at_ms',
      'expires_at_ms',
      'consumed',
    });
    return ForgeDeviceIdentityChallenge(
      challengeID: _text(json['challenge_id']),
      challengeSHA256: _text(json['challenge_sha256']),
      issuedAtMS: _uint64(json['issued_at_ms']),
      expiresAtMS: _uint64(json['expires_at_ms']),
      consumed: _bool(json['consumed']),
    );
  }
}

class ForgeDeviceIdentityProof {
  final String deviceID;
  final String keyID;
  final String publicKeySHA256;
  final ForgeDeviceOwner owner;
  final String challengeID;
  final String challengeSHA256;
  final String proofSHA256;
  final BigInt issuedAtMS;
  final BigInt expiresAtMS;

  const ForgeDeviceIdentityProof({
    required this.deviceID,
    required this.keyID,
    required this.publicKeySHA256,
    required this.owner,
    required this.challengeID,
    required this.challengeSHA256,
    required this.proofSHA256,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory ForgeDeviceIdentityProof.fromJson(Object? value) {
    final json = _object(value, 'identity proof');
    _exactKeys(json, {
      'device_id',
      'key_id',
      'public_key_sha256',
      'owner',
      'challenge_id',
      'challenge_sha256',
      'proof_sha256',
      'issued_at_ms',
      'expires_at_ms',
    });
    return ForgeDeviceIdentityProof(
      deviceID: _text(json['device_id']),
      keyID: _text(json['key_id']),
      publicKeySHA256: _text(json['public_key_sha256']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      challengeID: _text(json['challenge_id']),
      challengeSHA256: _text(json['challenge_sha256']),
      proofSHA256: _text(json['proof_sha256']),
      issuedAtMS: _uint64(json['issued_at_ms']),
      expiresAtMS: _uint64(json['expires_at_ms']),
    );
  }
}

class ForgeDeviceIdentityProofDecision {
  final bool identityBound;
  final bool approvalRequired;
  final String reason;

  const ForgeDeviceIdentityProofDecision({
    required this.identityBound,
    required this.approvalRequired,
    required this.reason,
  });
}

class ForgeDeviceIdentityProofError implements Exception {
  final String code;

  const ForgeDeviceIdentityProofError(this.code);

  @override
  String toString() => 'ForgeDeviceIdentityProofError($code)';
}

/// Evaluates structural binding against caller-supplied facts.
///
/// This function intentionally has no clock, storage, network, cryptography,
/// challenge-consumption, approval-write, inventory, or execution effect.
ForgeDeviceIdentityProofDecision evaluateForgeDeviceIdentityProof({
  required ForgeDeviceOwner owner,
  required ForgeDeviceIdentityBinding device,
  required ForgeDeviceIdentityChallenge challenge,
  required ForgeDeviceIdentityProof proof,
  required BigInt nowMS,
}) {
  _validateIdentityInputs(owner, device, challenge, proof);
  _validateCredentialState(device.credentialState);
  _validateChallenge(challenge, proof, nowMS);
  _validateProofWindow(proof, nowMS);
  final approvalRequired = _approvalRequired(device.approvalState);
  return ForgeDeviceIdentityProofDecision(
    identityBound: true,
    approvalRequired: approvalRequired,
    reason: approvalRequired ? 'bound_pending_approval' : 'bound_approved',
  );
}

void _validateIdentityInputs(
  ForgeDeviceOwner owner,
  ForgeDeviceIdentityBinding device,
  ForgeDeviceIdentityChallenge challenge,
  ForgeDeviceIdentityProof proof,
) {
  if (owner != device.owner || owner != proof.owner) {
    throw const ForgeDeviceIdentityProofError('owner_mismatch');
  }
  if (proof.deviceID != device.deviceID) {
    throw const ForgeDeviceIdentityProofError('device_mismatch');
  }
  if (proof.keyID != device.keyID ||
      proof.publicKeySHA256 != device.publicKeySHA256) {
    throw const ForgeDeviceIdentityProofError('key_mismatch');
  }
  if (!_validBinding(device) ||
      !_validProof(proof) ||
      !_validChallengeShape(challenge)) {
    throw const ForgeDeviceIdentityProofError('invalid_binding');
  }
}

void _validateCredentialState(String state) {
  switch (state) {
    case 'active':
      return;
    case 'revoked':
      throw const ForgeDeviceIdentityProofError('credential_revoked');
    case 'expired':
      throw const ForgeDeviceIdentityProofError('credential_expired');
    default:
      throw const ForgeDeviceIdentityProofError('unknown_credential_state');
  }
}

void _validateChallenge(
  ForgeDeviceIdentityChallenge challenge,
  ForgeDeviceIdentityProof proof,
  BigInt nowMS,
) {
  if (proof.challengeID != challenge.challengeID ||
      proof.challengeSHA256 != challenge.challengeSHA256) {
    throw const ForgeDeviceIdentityProofError('challenge_mismatch');
  }
  if (challenge.consumed) {
    throw const ForgeDeviceIdentityProofError('challenge_replayed');
  }
  if (nowMS < challenge.issuedAtMS) {
    throw const ForgeDeviceIdentityProofError('challenge_not_yet_valid');
  }
  if (nowMS >= challenge.expiresAtMS) {
    throw const ForgeDeviceIdentityProofError('challenge_expired');
  }
}

void _validateProofWindow(ForgeDeviceIdentityProof proof, BigInt nowMS) {
  if (nowMS < proof.issuedAtMS) {
    throw const ForgeDeviceIdentityProofError('proof_not_yet_valid');
  }
  if (nowMS >= proof.expiresAtMS) {
    throw const ForgeDeviceIdentityProofError('proof_expired');
  }
}

bool _approvalRequired(String state) => switch (state) {
  'approved' => false,
  'pending' => true,
  _ => throw const ForgeDeviceIdentityProofError('unknown_approval_state'),
};

bool _validBinding(ForgeDeviceIdentityBinding device) =>
    device.deviceID.isNotEmpty &&
    device.keyID.isNotEmpty &&
    _validDigest(device.publicKeySHA256);

bool _validProof(ForgeDeviceIdentityProof proof) =>
    proof.deviceID.isNotEmpty &&
    proof.keyID.isNotEmpty &&
    _validDigest(proof.publicKeySHA256) &&
    proof.challengeID.isNotEmpty &&
    _validDigest(proof.challengeSHA256) &&
    _validDigest(proof.proofSHA256) &&
    proof.issuedAtMS < proof.expiresAtMS;

bool _validChallengeShape(ForgeDeviceIdentityChallenge challenge) =>
    challenge.challengeID.isNotEmpty &&
    _validDigest(challenge.challengeSHA256) &&
    challenge.issuedAtMS < challenge.expiresAtMS;

bool _validDigest(String value) =>
    value.length == forgeDeviceIdentityProofDigestLength &&
    value.codeUnits.every(
      (code) => code >= 0x30 && code <= 0x39 || code >= 0x61 && code <= 0x66,
    );

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Expected Forge $label object.');
  }
  return Map<String, dynamic>.from(value);
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge device identity fields.');
  }
}

String _text(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge device identity text.');
  }
  return value;
}

bool _bool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge device identity boolean.');
  }
  return value;
}

BigInt _uint64(Object? value) {
  final number = value is BigInt
      ? value
      : value is int
      ? BigInt.from(value)
      : null;
  if (number == null || number < BigInt.zero || number > _identityMaxUint64) {
    throw const FormatException('Invalid Forge device identity integer.');
  }
  return number;
}

/// Decodes identity fixture text without rounding a uint64 JSON literal.
Object? decodeForgeDeviceIdentityJSON(String source) {
  final marked = source.replaceAll(
    _identityMaxUint64Literal,
    '"$_identityMaxUint64Marker"',
  );
  return _restoreIdentityUint64Markers(jsonDecode(marked));
}

Object? _restoreIdentityUint64Markers(Object? value) {
  if (value is String && value == _identityMaxUint64Marker) {
    return _identityMaxUint64;
  }
  if (value is List) {
    return value.map(_restoreIdentityUint64Markers).toList(growable: false);
  }
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(
          entry.key as String,
          _restoreIdentityUint64Markers(entry.value),
        ),
      ),
    );
  }
  return value;
}
