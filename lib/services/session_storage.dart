import 'session_storage_memory.dart'
    if (dart.library.js_interop) 'session_storage_web.dart'
    as implementation;

/// Tab-scoped storage abstraction used by [Session].
///
/// Browser builds delegate to `window.sessionStorage`; VM and native builds
/// intentionally expose no persistent store because browser redirect
/// continuity does not exist there.
class SessionStorage {
  static String? getItem(String key) => implementation.getItem(key);

  static void setItem(String key, String value) =>
      implementation.setItem(key, value);

  static void removeItem(String key) => implementation.removeItem(key);
}
