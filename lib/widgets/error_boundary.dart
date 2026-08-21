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
  String? _error;
  // 保存上一个全局 handler（链式 restore，避免嵌套边界互相覆盖）。
  FlutterExceptionHandler? _previousHandler;

  @override
  void initState() {
    super.initState();
    // Register error handler for this zone
    _previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (mounted) {
        setState(() => _error = details.exceptionAsString());
      }
    };
  }

  @override
  void dispose() {
    // Restore the previous handler (not the global default), so nested
    // boundaries and app-level handlers keep working.
    FlutterError.onError = _previousHandler ?? FlutterError.presentError;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
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
              const SizedBox(height: 8),
              Text(
                _error!.length > 200
                    ? '${_error!.substring(0, 200)}...'
                    : _error!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _error = null),
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
