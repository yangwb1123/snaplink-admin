import 'dart:async';

import 'connectivity_platform.dart' as platform;

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
  late final void Function() _cancelPlatformListener;

  /// Stream of connectivity changes. `true` = online, `false` = offline.
  Stream<bool> get onStatusChanged => _controller.stream;

  /// Current connectivity status. Cached for synchronous access.
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void _init() {
    _isOnline = platform.isOnline;
    _cancelPlatformListener = platform.listen((isOnline) {
      _isOnline = isOnline;
      if (!_controller.isClosed) _controller.add(isOnline);
    });
  }

  /// Clean up resources.
  void dispose() {
    _cancelPlatformListener();
    _controller.close();
  }
}
