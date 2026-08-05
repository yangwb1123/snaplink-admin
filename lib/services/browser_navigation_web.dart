import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _locationChangeEvent = 'snaplink-location-change';

Uri currentUri() => Uri.base;

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

bool assignExternalLocation(Uri target) {
  if (target.scheme != 'https' ||
      target.host.isEmpty ||
      target.userInfo.isNotEmpty) {
    return false;
  }
  web.window.location.href = target.toString();
  return true;
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

/// Test-only hook; a real browser always reflects the current document URL.
void resetForTest() {}
