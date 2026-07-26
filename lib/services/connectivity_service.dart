import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Monitors browser online/offline status using the Web API.
///
/// Provides a reactive stream of connectivity changes and a synchronous
/// check for the current status. Works entirely on the existing `web`
/// package dependency — no extra packages required.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._() {
    _init();
  }

  final _controller = StreamController<bool>.broadcast();

  /// Stream of connectivity changes. `true` = online, `false` = offline.
  Stream<bool> get onStatusChanged => _controller.stream;

  /// Current connectivity status. Cached for synchronous access.
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void _init() {
    // Use browser's online/offline events
    web.window.addEventListener('online', ((_) {
      _isOnline = true;
      _controller.add(true);
    }).toJS);

    web.window.addEventListener('offline', ((_) {
      _isOnline = false;
      _controller.add(false);
    }).toJS);

    // Initialize with current browser state
    _isOnline = web.window.navigator.onLine;
  }

  /// Clean up resources.
  void dispose() {
    _controller.close();
  }
}
