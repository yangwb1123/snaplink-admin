class WebAuthnAssertion {
  static Future<String> request(Object options, {String? mediation}) {
    throw StateError('Passkey authentication requires WebAuthn in a browser.');
  }
}
