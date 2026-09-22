import 'dart:async';

import 'package:sso_admin/services/forge_refresh_lock.dart';

/// Deterministic in-memory stand-in for the desktop lock in unit tests.
final class MemoryForgeRefreshLock implements ForgeRefreshLock {
  Future<void> _tail = Future<void>.value();
  int active = 0;
  int maxActive = 0;
  int acquisitions = 0;

  @override
  Future<T> synchronized<T>(Future<T> Function() action) async {
    final predecessor = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await predecessor;

    active++;
    acquisitions++;
    if (active > maxActive) maxActive = active;
    try {
      return await action();
    } finally {
      active--;
      release.complete();
    }
  }
}
