import 'package:flutter/widgets.dart';

import 'app_navigator.dart';

Uri _currentUri = Uri.base;

/// Same-document navigation history recorded by [pushState].
///
/// Native shells own the real browser history, so this in-memory stack is
/// the source a back() replays. The initial [_currentUri] (bundle/base
/// URL) is never a product route and is skipped by [back].
final List<Uri> _history = <Uri>[];

final _locationListeners = <void Function()>{};

Uri currentUri() => _currentUri;

void pushState(String path) {
  _history.add(_currentUri);
  _setSameDocumentLocation(path);
}

void replaceState(String path) => _setSameDocumentLocation(path);

bool back() {
  while (_history.isNotEmpty) {
    final previous = _history.removeLast();
    // The untouched initial base (file:// bundle URL, test host) is not a
    // product route; keep popping so back never lands outside the app.
    if (previous.scheme != 'file' &&
        previous.path.isNotEmpty &&
        previous.path != '/') {
      _setSameDocumentLocation(previous.toString());
      return true;
    }
  }
  return false;
}

void assignLocation(String path) => _replaceRoute(path);

bool assignExternalLocation(Uri target) => false;

void replaceLocation(String path) => _replaceRoute(path);

void Function() listenToPopState(void Function() listener) =>
    listenToLocationChange(listener);

void Function() listenToLocationChange(void Function() listener) {
  _locationListeners.add(listener);
  return () => _locationListeners.remove(listener);
}

void _setSameDocumentLocation(String location) {
  _currentUri = _parseLocation(location);
  for (final listener in List<void Function()>.of(_locationListeners)) {
    listener();
  }
}

void _replaceRoute(String location) {
  _currentUri = _parseLocation(location);
  // Auth guards can request navigation from initState. Deferring the route
  // replacement avoids mutating Navigator's overlay while it is still
  // mounting the current product entry.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = AppNavigator.key.currentState;
    if (navigator == null || !navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil(location, (_) => false);
  });
}

/// Clears in-memory location state so widget tests start from a clean URL.
void resetForTest() {
  _currentUri = Uri.base;
  _history.clear();
  _locationListeners.clear();
}

Uri _parseLocation(String location) => Uri.tryParse(location) ?? Uri(path: '/');
