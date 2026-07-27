import 'local_storage_memory.dart'
    if (dart.library.js_interop) 'local_storage_web.dart'
    as implementation;

/// Cross-platform local storage wrapper.
///
/// Browser builds use `window.localStorage`. VM and other non-web builds use
/// an in-memory implementation, which also keeps service tests deterministic.
class LocalStorage {
  /// Get an item from local storage.
  static String? getItem(String key) => implementation.getItem(key);

  /// Set an item in local storage.
  static void setItem(String key, String value) =>
      implementation.setItem(key, value);

  /// Remove an item from local storage.
  static void removeItem(String key) => implementation.removeItem(key);

  /// Snapshot the keys currently visible to this origin.
  static List<String> keys() => implementation.keys();
}
