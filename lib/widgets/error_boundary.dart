import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

/// Error boundary widget that catches exceptions from its child subtree.
///
/// When a wrapped widget throws an exception during build, this boundary
/// catches it and displays a fallback UI instead of crashing the entire
/// page. This prevents a single tab from breaking the entire dashboard.
class ErrorBoundary extends StatefulWidget {
  /// 受保护的子树（构建期异常被捕获并显示兜底 UI）。
  final Widget child;

  /// 兜底标题（i18n 键）；null = 默认 'Something went wrong'。
  final String? label;

  const ErrorBoundary({super.key, required this.child, this.label});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  bool _errorPending = false;
  late final _BoundaryErrorHandler _handler;

  @override
  void initState() {
    super.initState();
    _handler = _BoundaryErrorHandler(_scheduleError);
  }

  void _scheduleError() {
    if (!mounted || _hasError || _errorPending) return;
    _errorPending = true;
    // Framework errors may arrive while a descendant is building. Updating
    // this ancestor synchronously would itself cause a build-phase error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _errorPending = false;
      setState(() => _hasError = true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _handler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              LocalizedText(
                widget.label ?? 'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _hasError = false),
                icon: const Icon(Icons.refresh),
                label: const LocalizedText('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}

/// A detachable link in the global handler chain. Stale callbacks retained by
/// external handlers keep forwarding, but never retain a disposed State.
class _BoundaryErrorHandler {
  static final _active = <_BoundaryErrorHandler>[];
  static final _notified = Set<FlutterErrorDetails>.identity();

  final _forwarding = Set<FlutterErrorDetails>.identity();
  FlutterExceptionHandler? _previousHandler;
  VoidCallback? _onError;
  late final FlutterExceptionHandler handler = _handleError;

  _BoundaryErrorHandler(VoidCallback onError)
    : _onError = onError,
      _previousHandler = FlutterError.onError {
    _active.add(this);
    FlutterError.onError = handler;
  }

  void _handleError(FlutterErrorDetails details) {
    // An app handler may forward back through FlutterError.reportError.
    // Guard only this in-flight report; distinct and later errors still flow.
    if (!_forwarding.add(details)) return;
    final notify = _onError;
    final didNotify = notify != null && _notified.add(details);
    try {
      // Preserve the newest boundary's fallback rather than also replacing
      // every enclosing boundary when forwarding to the app handler.
      if (didNotify) notify();
      _previousHandler?.call(details);
    } finally {
      if (didNotify) _notified.remove(details);
      _forwarding.remove(details);
    }
  }

  void dispose() {
    _onError = null;
    _active.remove(this);
    // Unlink out-of-order disposal so a later restore cannot resurrect us.
    for (final link in _active) {
      if (identical(link._previousHandler, handler)) {
        link._previousHandler = _previousHandler;
      }
    }
    // Another owner may have replaced the global handler after installation.
    if (identical(FlutterError.onError, handler)) {
      FlutterError.onError = _previousHandler;
    }
  }
}
