import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Cross-tab synchronization service.
///
/// Uses the browser's `storage` event to detect changes made in
/// other tabs/windows and notifies listeners. This keeps the admin
/// console data consistent when the same user opens multiple tabs.
///
/// The `storage` event fires automatically when localStorage is
/// modified in another tab — no custom event dispatching needed.
class CrossTabSync {
  static final CrossTabSync _instance = CrossTabSync._();
  factory CrossTabSync() => _instance;
  CrossTabSync._();

  final _controller = StreamController<SyncEvent>.broadcast();

  /// Stream of sync events from other tabs.
  Stream<SyncEvent> get onSync => _controller.stream;

  bool _initialized = false;
  dynamic _storageHandler; // JS function reference

  /// Start listening for cross-tab changes.
  void init() {
    if (_initialized) return;
    _initialized = true;

    _storageHandler = ((web.StorageEvent event) {
      if (event.key != null && event.newValue != null) {
        _controller.add(SyncEvent(
          key: event.key!,
          oldValue: event.oldValue,
          newValue: event.newValue,
        ));
      }
    }).toJS;

    web.window.addEventListener('storage', _storageHandler);
  }

  /// Broadcast a change to other tabs via localStorage.
  /// The value is written to localStorage, which triggers the
  /// `storage` event in all OTHER tabs (but not the current one).
  static void broadcast(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  /// Remove a synced key from localStorage.
  static void remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }

  /// Clean up.
  void dispose() {
    if (_initialized && _storageHandler != null) {
      web.window.removeEventListener('storage', _storageHandler);
      _initialized = false;
    }
    _controller.close();
  }
}

/// A sync event triggered by changes in another tab.
class SyncEvent {
  final String key;
  final String? oldValue;
  final String? newValue;

  const SyncEvent({
    required this.key,
    this.oldValue,
    this.newValue,
  });

  /// Parse the new value as JSON.
  Map<String, dynamic>? get jsonValue {
    if (newValue == null) return null;
    try {
      return jsonDecode(newValue!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
