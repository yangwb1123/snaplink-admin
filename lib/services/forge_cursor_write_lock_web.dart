import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> withLock(String key, Future<void> Function() write) async {
  var entered = false;
  JSPromise<JSAny?> grantLock() {
    entered = true;
    return write().toJS;
  }

  try {
    await web.window.navigator.locks.request(key, grantLock.toJS).toDart;
  } catch (_) {
    if (entered) rethrow;
    // Older or embedded browsers may lack Web Locks. Cursor regression can
    // only cause replay, so retain best-effort persistence there.
    await write();
  }
}
