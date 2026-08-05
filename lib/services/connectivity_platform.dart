import 'connectivity_platform_stub.dart'
    if (dart.library.js_interop) 'connectivity_platform_web.dart'
    as platform;

bool get isOnline => platform.isOnline;

void Function() listen(void Function(bool isOnline) listener) =>
    platform.listen(listener);

/// Test-only hook: simulates a browser online/offline event (no-op on web).
void testEmitStatus(bool isOnline) => platform.testEmitStatus(isOnline);

/// Test-only hook: restores stub state between tests (no-op on web).
void resetForTest() => platform.resetForTest();

/// Test-only introspection.
int get listenerCount => platform.listenerCount;
