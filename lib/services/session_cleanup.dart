import 'dart:async';

import '../session.dart';
import 'forge_credential_store.dart';

/// Clears every in-memory OAuth slot and the native Forge credential record.
Future<void> clearAllSessions({ForgeCredentialStore? credentialStore}) async {
  Session.clear();
  await (credentialStore ?? ForgeCredentialStore()).clear();
}

/// Starts best-effort credential cleanup from synchronous error callbacks.
void clearAllSessionsBestEffort({ForgeCredentialStore? credentialStore}) {
  unawaited(
    clearAllSessions(
      credentialStore: credentialStore,
    ).catchError((Object _) {}),
  );
}
