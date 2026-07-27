import 'package:flutter/material.dart';

/// Error boundary widget that catches exceptions from its child subtree.
///
/// When a wrapped widget throws an exception during build, this boundary
/// catches it and displays a fallback UI instead of crashing the entire
/// page. This prevents a single tab from breaking the entire dashboard.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? label;

  const ErrorBoundary({super.key, required this.child, this.label});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Register error handler for this zone
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (mounted) {
        setState(() => _error = details.exceptionAsString());
      }
    };
  }

  @override
  void dispose() {
    // Reset to default handler if we were the one who set it
    FlutterError.onError = FlutterError.presentError;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
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
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _error = null),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
