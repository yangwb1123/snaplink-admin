import 'shortcut_platform_stub.dart'
    if (dart.library.js_interop) 'shortcut_platform_web.dart'
    as platform;

void Function() listen(
  void Function(String key, bool controlPressed, void Function() preventDefault)
  listener,
) => platform.listen(listener);

/// Test-only hook: dispatches a synthetic key event (no-op on web).
void testEmitKey(String key, bool controlPressed) =>
    platform.testEmitKey(key, controlPressed);

/// Test-only hook: clears listeners between tests (no-op on web).
void resetForTest() => platform.resetForTest();
