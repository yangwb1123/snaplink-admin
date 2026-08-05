import 'dart:js_interop';

import 'package:web/web.dart' as web;

void Function() listen(
  void Function(String key, bool controlPressed, void Function() preventDefault)
  listener,
) {
  final jsListener = ((web.KeyboardEvent event) {
    listener(
      event.key,
      event.ctrlKey || event.metaKey,
      () => event.preventDefault(),
    );
  }).toJS;
  web.window.addEventListener('keydown', jsListener);
  return () => web.window.removeEventListener('keydown', jsListener);
}

/// Test-only hook; a real browser dispatches real keyboard events.
void testEmitKey(String key, bool controlPressed) {}
void resetForTest() {}
