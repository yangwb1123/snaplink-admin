import 'dart:async';

import 'forge_cursor_write_lock_stub.dart'
    if (dart.library.js_interop) 'forge_cursor_write_lock_web.dart'
    as implementation;

final Map<String, Future<void>> _writesByKey = {};

Future<void> withForgeCursorWriteLock(
  String key,
  Future<void> Function() write,
) async {
  final previous = _writesByKey[key] ?? Future<void>.value();
  final release = Completer<void>();
  _writesByKey[key] = release.future;
  await previous;
  try {
    await implementation.withLock(key, write);
  } finally {
    release.complete();
    if (identical(_writesByKey[key], release.future)) {
      _writesByKey.remove(key);
    }
  }
}
