import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _locationChangeEvent = 'snaplink-location-change';

void pushState(String path) {
  web.window.history.pushState(null, '', path);
  _dispatchLocationChange();
}

void replaceState(String path) {
  web.window.history.replaceState(null, '', path);
  _dispatchLocationChange();
}

void assignLocation(String path) {
  web.window.location.href = path;
}

void replaceLocation(String path) {
  web.window.location.replace(path);
}

void Function() listenToPopState(void Function() listener) {
  final jsListener = ((web.Event _) => listener()).toJS;
  web.window.addEventListener('popstate', jsListener);
  return () => web.window.removeEventListener('popstate', jsListener);
}

void Function() listenToLocationChange(void Function() listener) {
  final popStateListener = ((web.Event _) => listener()).toJS;
  final internalListener = ((web.Event _) => listener()).toJS;
  web.window.addEventListener('popstate', popStateListener);
  web.window.addEventListener(_locationChangeEvent, internalListener);
  return () {
    web.window.removeEventListener('popstate', popStateListener);
    web.window.removeEventListener(_locationChangeEvent, internalListener);
  };
}

void _dispatchLocationChange() {
  web.window.dispatchEvent(web.Event(_locationChangeEvent));
}
