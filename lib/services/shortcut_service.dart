import 'package:flutter/material.dart';

import 'shortcut_platform.dart' as platform;

/// Keyboard shortcut service for admin console.
///
/// Registers global keyboard listeners for common operations:
/// - Ctrl+N: Create new resource
/// - Ctrl+F: Focus search
/// - Ctrl+R: Refresh
/// - Escape: Close dialog / cancel
/// - Ctrl+1-9: Navigate to tab
class ShortcutService {
  static final ShortcutService _instance = ShortcutService._();
  factory ShortcutService() => _instance;
  ShortcutService._();

  bool _initialized = false;
  void Function()? _cancelKeyListener;
  VoidCallback? _onCreate;
  VoidCallback? _onRefresh;
  VoidCallback? _onCommandPalette;
  VoidCallback? _onShowShortcuts;
  VoidCallback? _onSearch;
  VoidCallback? _onEscape;
  void Function(int tabIndex)? _onNavigate;

  /// Initialize the service with callbacks.
  void init({
    VoidCallback? onCreate,
    VoidCallback? onRefresh,
    VoidCallback? onSearch,
    VoidCallback? onEscape,
    VoidCallback? onCommandPalette,
    VoidCallback? onShowShortcuts,
    void Function(int tabIndex)? onNavigate,
  }) {
    if (_initialized) return;
    _initialized = true;

    _onCreate = onCreate;
    _onRefresh = onRefresh;
    _onSearch = onSearch;
    _onEscape = onEscape;
    _onCommandPalette = onCommandPalette;
    _onShowShortcuts = onShowShortcuts;
    _onNavigate = onNavigate;

    _cancelKeyListener = platform.listen(_onKeyDown);
  }

  void _onKeyDown(
    String key,
    bool controlPressed,
    void Function() preventDefault,
  ) {
    if (controlPressed) {
      switch (key) {
        case 'k':
        case 'K':
          preventDefault();
          _onCommandPalette?.call();
          break;
        case 'n':
        case 'N':
          preventDefault();
          _onCreate?.call();
          break;
        case 'f':
        case 'F':
          preventDefault();
          _onSearch?.call();
          break;
        case 'r':
        case 'R':
          preventDefault();
          _onRefresh?.call();
          break;
      }
      // Ctrl+1 through Ctrl+9 for tab navigation
      final digit = int.tryParse(key);
      if (digit != null && digit >= 1 && digit <= 9) {
        preventDefault();
        _onNavigate?.call(digit);
      }
    }

    if (key == 'Escape') {
      _onEscape?.call();
    }

    if (key == '?' && controlPressed) {
      preventDefault();
      _onShowShortcuts?.call();
    }
  }

  /// Clean up event listener.
  void dispose() {
    if (_initialized) {
      _cancelKeyListener?.call();
      _cancelKeyListener = null;
      _initialized = false;
    }
  }
}
