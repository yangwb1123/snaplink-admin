import 'package:flutter/foundation.dart';

/// Cross-platform local storage wrapper.
///
/// Uses `window.localStorage` on web via the `web` package.
/// Falls back to in-memory storage on non-web platforms.
class LocalStorage {
  static final Map<String, String> _memoryStore = {};

  /// Get an item from local storage.
  static String? getItem(String key) {
    if (kIsWeb) {
      return _webGetItem(key);
    }
    return _memoryStore[key];
  }

  /// Set an item in local storage.
  static void setItem(String key, String value) {
    if (kIsWeb) {
      _webSetItem(key, value);
    } else {
      _memoryStore[key] = value;
    }
  }

  /// Remove an item from local storage.
  static void removeItem(String key) {
    if (kIsWeb) {
      _webRemoveItem(key);
    } else {
      _memoryStore.remove(key);
    }
  }

  // Web-specific implementations using the web package
  static String? _webGetItem(String key) {
    try {
      // Use dart:js_interop with the global window object
      // ignore: undefined_identifier
      final storage = _windowStorage();
      if (storage != null) {
        return storage.getItem(key);
      }
    } catch (_) {}
    return null;
  }

  static void _webSetItem(String key, String value) {
    try {
      final storage = _windowStorage();
      if (storage != null) {
        storage.setItem(key, value);
      }
    } catch (_) {}
  }

  static void _webRemoveItem(String key) {
    try {
      final storage = _windowStorage();
      if (storage != null) {
        storage.removeItem(key);
      }
    } catch (_) {}
  }

  static dynamic _windowStorage() {
    try {
      // Access window.localStorage via the global scope
      // This works when compiled to web with dart:js_interop
      final window = _globalWindow();
      return window.localStorage;
    } catch (_) {
      return null;
    }
  }

  static dynamic _globalWindow() {
    // Use dart:js_interop to access the global window object
    // ignore: undefined_identifier
    return globalThis;
  }
}
