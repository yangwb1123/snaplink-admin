import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'cross_tab_sync_stub.dart'
    if (dart.library.js_interop) 'cross_tab_sync_web.dart'
    as platform;
import 'local_storage.dart';

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
  void Function()? _cancelStorageListener;

  /// Start listening for cross-tab changes.
  void init() {
    if (_initialized) return;
    _initialized = true;

    _cancelStorageListener = platform.listenToStorage((
      key,
      oldValue,
      newValue,
    ) {
      if (key != null && newValue != null) {
        _controller.add(
          SyncEvent(key: key, oldValue: oldValue, newValue: newValue),
        );
      }
    });
  }

  /// Broadcast a change to other tabs via localStorage.
  /// The value is written to localStorage, which triggers the
  /// `storage` event in all OTHER tabs (but not the current one).
  static void broadcast(String key, String value) {
    try {
      LocalStorage.setItem(key, value);
    } catch (e) { debugPrint('cross_tab_sync error: $e'); }
  }

  /// Remove a synced key from localStorage.
  static void remove(String key) {
    try {
      LocalStorage.removeItem(key);
    } catch (e) { debugPrint('cross_tab_sync error: $e'); }
  }

  /// Clean up.
  void dispose() {
    if (_initialized) {
      _cancelStorageListener?.call();
      _cancelStorageListener = null;
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

  const SyncEvent({required this.key, this.oldValue, this.newValue});

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
