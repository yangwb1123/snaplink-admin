/// A credential returned by a platform password manager.
class BrowserPasswordCredential {
  final String username;
  final String password;

  const BrowserPasswordCredential({
    required this.username,
    required this.password,
  });
}

/// Non-web builds rely on the native text-input autofill implementation.
abstract final class BrowserPasswordManager {
  static void prepareLoginForm() {}

  static Future<BrowserPasswordCredential?> read() async => null;

  static Future<void> save({
    required String username,
    required String password,
  }) async {}
}
