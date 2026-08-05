import 'package:flutter/foundation.dart' show kIsWeb;

import '../../services/local_storage.dart';

/// Stores the opaque, bearer-equivalent MFA-skip grant only after a user has
/// explicitly opted to trust this browser. The grant is scoped by client ID.
class TrustedDeviceToken {
  static const _prefix = 'snaplink_trusted_device:';

  static String? read(String clientId) {
    if (!kIsWeb || clientId.isEmpty) return null;
    return LocalStorage.getItem(_key(clientId));
  }

  static void store(String clientId, String token) {
    if (!kIsWeb || clientId.isEmpty || token.isEmpty) return;
    LocalStorage.setItem(_key(clientId), token);
  }

  static void clear(String clientId) {
    if (!kIsWeb || clientId.isEmpty) return;
    LocalStorage.removeItem(_key(clientId));
  }

  static String _key(String clientId) =>
      '$_prefix${Uri.encodeComponent(clientId)}';
}
