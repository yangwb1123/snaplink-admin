import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The generated web package exposes the password credential data dictionary,
/// but not the password-specific properties on the returned Credential.
/// Keep this narrow extension local to the browser password-manager adapter.
extension type _PasswordCredential(web.Credential _) implements web.Credential {
  external String get password;
}

/// Browser-managed username/password credentials.
///
/// The application never persists the password. Unsupported browsers and
/// insecure origins simply fall back to Flutter's platform autofill context.
abstract final class BrowserPasswordManager {
  static Future<BrowserPasswordCredential?> read() async {
    try {
      final credential = await web.window.navigator.credentials
          .get(
            web.CredentialRequestOptions(password: true, mediation: 'optional'),
          )
          .toDart;
      if (credential == null || credential.type != 'password') return null;
      final passwordCredential = credential as _PasswordCredential;
      final username = credential.id.trim();
      final password = passwordCredential.password;
      if (username.isEmpty || password.isEmpty) return null;
      return BrowserPasswordCredential(username: username, password: password);
    } catch (_) {
      // Credential Management is unavailable on some browsers/origins and
      // may reject a silent read. Flutter's normal autofill remains enabled.
      return null;
    }
  }

  static Future<void> save({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) return;

    try {
      final data = web.PasswordCredentialData(
        id: normalizedUsername,
        origin: web.window.location.origin,
        password: password,
      );
      final credential = await web.window.navigator.credentials
          .create(web.CredentialCreationOptions(password: data))
          .toDart;
      if (credential == null) return;
      await web.window.navigator.credentials.store(credential).toDart;
    } catch (_) {
      // The explicit checkbox is best effort: do not block or fail a login
      // when the browser declines to expose its password manager.
    }
  }
}

class BrowserPasswordCredential {
  final String username;
  final String password;

  const BrowserPasswordCredential({
    required this.username,
    required this.password,
  });
}
