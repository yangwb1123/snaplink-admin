import 'dart:async';

import 'package:sso_admin/services/forge_credential_store.dart';

class MemoryForgeCredentialBackend implements ForgeCredentialBackend {
  String? value;
  Future<void>? readBarrier;
  Future<void>? writeBarrier;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<String?> read(String key) async {
    await readBarrier;
    if (failRead) throw StateError('simulated secure-store failure');
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    await writeBarrier;
    if (failWrite) throw StateError('simulated secure-store failure');
    this.value = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('simulated secure-store failure');
    value = null;
  }
}
