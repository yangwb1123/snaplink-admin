class WebAuthnRegistration {
  static Future<Map<String, dynamic>> create(Object options) {
    throw StateError('Passkey enrollment requires WebAuthn in a browser.');
  }
}
