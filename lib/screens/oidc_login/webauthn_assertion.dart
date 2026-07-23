import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Runs a browser WebAuthn assertion ceremony and returns Snaplink's expected
/// JSON representation of the signed credential response.
class WebAuthnAssertion {
  static Future<String> request(Object options, {String? mediation}) async {
    final envelope = _asMap(options);
    final publicKey = _asMap(envelope['publicKey'] ?? envelope);
    final request = web.PublicKeyCredentialRequestOptions(
      challenge: _bytes(publicKey['challenge']).toJS,
    );
    final timeout = _int(publicKey['timeout']);
    if (timeout != null) request.timeout = timeout;
    final rpId = publicKey['rpId']?.toString();
    if (rpId != null && rpId.isNotEmpty) request.rpId = rpId;
    final descriptors = _descriptors(publicKey['allowCredentials']);
    if (descriptors.isNotEmpty) request.allowCredentials = descriptors.toJS;
    final verification = publicKey['userVerification']?.toString();
    if (verification != null && verification.isNotEmpty) {
      request.userVerification = verification;
    }
    final requestOptions = web.CredentialRequestOptions(publicKey: request);
    final requestedMediation = mediation ?? envelope['mediation']?.toString();
    if (requestedMediation != null && requestedMediation.isNotEmpty) {
      requestOptions.mediation = requestedMediation;
    }
    final credential = await web.window.navigator.credentials
        .get(requestOptions)
        .toDart;
    if (credential == null || credential.type != 'public-key') {
      throw StateError('No passkey assertion was returned.');
    }
    final publicKeyCredential = credential as web.PublicKeyCredential;
    final response =
        publicKeyCredential.response as web.AuthenticatorAssertionResponse;
    return jsonEncode({
      'id': publicKeyCredential.id,
      'rawId': _base64(publicKeyCredential.rawId),
      'type': publicKeyCredential.type,
      'response': {
        'clientDataJSON': _base64(response.clientDataJSON),
        'authenticatorData': _base64(response.authenticatorData),
        'signature': _base64(response.signature),
        if (response.userHandle != null)
          'userHandle': _base64(response.userHandle!),
      },
    });
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is String) value = jsonDecode(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Invalid WebAuthn options.');
  }

  static Uint8List _bytes(Object? value) {
    if (value is List) {
      return Uint8List.fromList(
        value.cast<num>().map((n) => n.toInt()).toList(),
      );
    }
    final encoded = value?.toString() ?? '';
    if (encoded.isEmpty) {
      throw const FormatException('WebAuthn challenge is missing.');
    }
    return base64Url.decode(base64Url.normalize(encoded));
  }

  static int? _int(Object? value) => switch (value) {
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };

  static List<web.PublicKeyCredentialDescriptor> _descriptors(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((raw) {
          final descriptor = Map<String, dynamic>.from(raw);
          final transports = descriptor['transports'];
          final result = web.PublicKeyCredentialDescriptor(
            type: descriptor['type']?.toString() ?? 'public-key',
            id: _bytes(descriptor['id']).toJS,
          );
          if (transports is List) {
            result.transports = transports
                .map((item) => item.toString().toJS)
                .toList()
                .toJS;
          }
          return result;
        })
        .toList(growable: false);
  }

  static String _base64(JSArrayBuffer buffer) =>
      base64Url.encode(buffer.toDart.asUint8List()).replaceAll('=', '');
}
