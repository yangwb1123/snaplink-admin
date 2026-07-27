import 'browser_navigation_stub.dart'
    if (dart.library.js_interop) 'browser_navigation_web.dart'
    as platform;

/// Browser history integration that remains safe to import on non-web targets.
///
/// The returned callbacks from [listenToPopState] and
/// [listenToLocationChange] must be invoked by widget owners during `dispose`
/// to release browser event listeners.
abstract final class BrowserNavigation {
  static void pushState(String path) => platform.pushState(path);

  /// Replaces the current in-app history entry without reloading the page.
  static void replaceState(String path) => platform.replaceState(path);

  static void assignLocation(String path) => platform.assignLocation(path);

  static void replaceLocation(String path) => platform.replaceLocation(path);

  static void Function() listenToPopState(void Function() listener) =>
      platform.listenToPopState(listener);

  /// Listens to every same-document location change.
  ///
  /// Browsers do not emit `popstate` for `history.pushState` or
  /// `history.replaceState`. This listener combines native back/forward
  /// navigation with the explicit event emitted by the methods above.
  static void Function() listenToLocationChange(void Function() listener) =>
      platform.listenToLocationChange(listener);
}
