/// VM stub for the browser keyboard platform. Keeps registered listeners so
/// tests can inject synthetic key events through [testEmitKey].
final _listeners =
    <
      void Function(
        String key,
        bool controlPressed,
        void Function() preventDefault,
      )
    >{};

void Function() listen(
  void Function(String key, bool controlPressed, void Function() preventDefault)
  listener,
) {
  _listeners.add(listener);
  return () => _listeners.remove(listener);
}

/// Test-only hook: dispatches a synthetic key event to every listener.
void testEmitKey(String key, bool controlPressed) {
  for (final listener
      in List<
        void Function(
          String key,
          bool controlPressed,
          void Function() preventDefault,
        )
      >.of(_listeners)) {
    listener(key, controlPressed, () {});
  }
}

/// Test-only hook: clears listeners between tests.
void resetForTest() {
  _listeners.clear();
}
