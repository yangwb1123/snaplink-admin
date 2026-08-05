import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Creates a browser passkey and returns its standard attestation JSON.
class WebAuthnRegistration {
  static Future<Map<String, dynamic>> create(Object options) async {
    final envelope = _asMap(options);
    final publicKey = _asMap(envelope['publicKey'] ?? envelope);
    final rpData = _asMap(publicKey['rp']);
    final userData = _asMap(publicKey['user']);
    final rp = web.PublicKeyCredentialRpEntity(
      name: rpData['name']?.toString() ?? 'Snaplink',
    );
    final rpId = rpData['id']?.toString();
    if (rpId != null && rpId.isNotEmpty) rp.id = rpId;
    final user = web.PublicKeyCredentialUserEntity(
      id: _bytes(userData['id']).toJS,
      name: userData['name']?.toString() ?? '',
      displayName: userData['displayName']?.toString() ?? '',
    );
    final credentialParameters = _parameters(publicKey['pubKeyCredParams']);
    if (credentialParameters.isEmpty) {
      throw const FormatException('Passkey algorithms are missing.');
    }
    final creation = web.PublicKeyCredentialCreationOptions(
      rp: rp,
      user: user,
      challenge: _bytes(publicKey['challenge']).toJS,
      pubKeyCredParams: credentialParameters.toJS,
    );
    _applyOptions(creation, publicKey);
    final credential = await web.window.navigator.credentials
        .create(web.CredentialCreationOptions(publicKey: creation))
        .toDart;
    if (credential == null || credential.type != 'public-key') {
      throw StateError('No passkey credential was created.');
    }
    final publicKeyCredential = credential as web.PublicKeyCredential;
    final response =
        publicKeyCredential.response as web.AuthenticatorAttestationResponse;
    return {
      'id': publicKeyCredential.id,
      'rawId': _base64(publicKeyCredential.rawId),
      'type': publicKeyCredential.type,
      'response': {
        'clientDataJSON': _base64(response.clientDataJSON),
        'attestationObject': _base64(response.attestationObject),
      },
    };
  }

  static void _applyOptions(
    web.PublicKeyCredentialCreationOptions creation,
    Map<String, dynamic> data,
  ) {
    final timeout = _int(data['timeout']);
    if (timeout != null) creation.timeout = timeout;
    final excluded = _descriptors(data['excludeCredentials']);
    if (excluded.isNotEmpty) creation.excludeCredentials = excluded.toJS;
    final attestation = data['attestation']?.toString();
    if (attestation != null && attestation.isNotEmpty) {
      creation.attestation = attestation;
    }
    final selectionData = data['authenticatorSelection'];
    if (selectionData is Map) {
      final selection = web.AuthenticatorSelectionCriteria();
      final value = Map<String, dynamic>.from(selectionData);
      final attachment = value['authenticatorAttachment']?.toString();
      final residentKey = value['residentKey']?.toString();
      final userVerification = value['userVerification']?.toString();
      if (attachment != null && attachment.isNotEmpty) {
        selection.authenticatorAttachment = attachment;
      }
      if (residentKey != null && residentKey.isNotEmpty) {
        selection.residentKey = residentKey;
      }
      if (value['requireResidentKey'] is bool) {
        selection.requireResidentKey = value['requireResidentKey'] as bool;
      }
      if (userVerification != null && userVerification.isNotEmpty) {
        selection.userVerification = userVerification;
      }
      creation.authenticatorSelection = selection;
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is String) value = jsonDecode(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Invalid passkey options.');
  }

  static Uint8List _bytes(Object? value) {
    if (value is List) {
      return Uint8List.fromList(
        value.cast<num>().map((number) => number.toInt()).toList(),
      );
    }
    final encoded = value?.toString() ?? '';
    if (encoded.isEmpty) {
      throw const FormatException('Passkey data is missing.');
    }
    return base64Url.decode(base64Url.normalize(encoded));
  }

  static List<web.PublicKeyCredentialParameters> _parameters(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((raw) {
          final data = Map<String, dynamic>.from(raw);
          final algorithm = _int(data['alg']);
          if (algorithm == null) {
            throw const FormatException('Invalid passkey algorithm.');
          }
          return web.PublicKeyCredentialParameters(
            type: data['type']?.toString() ?? 'public-key',
            alg: algorithm,
          );
        })
        .toList(growable: false);
  }

  static List<web.PublicKeyCredentialDescriptor> _descriptors(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((raw) {
          final data = Map<String, dynamic>.from(raw);
          return web.PublicKeyCredentialDescriptor(
            type: data['type']?.toString() ?? 'public-key',
            id: _bytes(data['id']).toJS,
          );
        })
        .toList(growable: false);
  }

  static int? _int(Object? value) => switch (value) {
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };

  static String _base64(JSArrayBuffer buffer) =>
      base64Url.encode(buffer.toDart.asUint8List()).replaceAll('=', '');
}
