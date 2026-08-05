/// VM stub for the browser online/offline platform. Always online unless a
/// test injects a change through [testEmitStatus].
bool _isOnline = true;

bool get isOnline => _isOnline;

final _listeners = <void Function(bool isOnline)>{};

void Function() listen(void Function(bool isOnline) listener) {
  _listeners.add(listener);
  return () => _listeners.remove(listener);
}

/// Test-only hook: simulates a browser online/offline event.
void testEmitStatus(bool isOnline) {
  _isOnline = isOnline;
  for (final listener in List<void Function(bool)>.of(_listeners)) {
    listener(isOnline);
  }
}

/// Test-only hook: restores the online state without clearing listeners —
/// ConnectivityService is a process-wide singleton, so clearing the listener
/// set here would silently detach widgets created by earlier tests.
void resetForTest() {
  _isOnline = true;
}

/// Test-only introspection.
int get listenerCount => _listeners.length;
