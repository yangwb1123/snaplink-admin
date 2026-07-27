import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get isOnline => web.window.navigator.onLine;

void Function() listen(void Function(bool isOnline) listener) {
  final onlineListener = ((web.Event _) => listener(true)).toJS;
  final offlineListener = ((web.Event _) => listener(false)).toJS;
  web.window.addEventListener('online', onlineListener);
  web.window.addEventListener('offline', offlineListener);
  return () {
    web.window.removeEventListener('online', onlineListener);
    web.window.removeEventListener('offline', offlineListener);
  };
}
