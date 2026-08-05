import 'dart:js_interop';

import 'package:web/web.dart' as web;

void Function() listenToStorage(
  void Function(String? key, String? oldValue, String? newValue) listener,
) {
  final handler = ((web.StorageEvent event) {
    listener(event.key, event.oldValue, event.newValue);
  }).toJS;
  web.window.addEventListener('storage', handler);
  return () => web.window.removeEventListener('storage', handler);
}
