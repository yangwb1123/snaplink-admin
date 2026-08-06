import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'empty_state.dart';

/// Unified three-state widget for async data loading.
///
/// Consolidates the common pattern:
/// ```
/// if (loading) show loader
/// else if (error) show error + retry
/// else if (empty) show empty state
/// else show data
/// ```
///
/// Usage:
/// ```dart
/// AsyncView<int>(
///   loading: _loading,
///   error: _error,
///   data: _items.isEmpty ? null : _items,
///   onRetry: _load,
///   emptyTitle: 'No items found',
///   dataBuilder: (items) => ListView(...),
/// )
/// ```
class AsyncView<T> extends StatelessWidget {
  final bool loading;
  final String? error;
  final T? data;
  final VoidCallback? onRetry;
  final String? emptyTitle;
  final String? emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Widget Function(T data) dataBuilder;

  const AsyncView({
    super.key,
    required this.loading,
    this.error,
    this.data,
    this.onRetry,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
    required this.dataBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Failed to load'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(error!),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.strings.retry),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final dataValue = data;
    if (dataValue == null || _isEmpty(dataValue)) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: context.tr(emptyTitle ?? 'No data'),
        subtitle: emptySubtitle == null ? null : context.tr(emptySubtitle!),
        actionLabel: emptyActionLabel == null
            ? null
            : context.tr(emptyActionLabel!),
        onAction: onEmptyAction,
      );
    }

    return dataBuilder(dataValue);
  }

  bool _isEmpty(T? data) {
    if (data == null) return true;
    if (data is Iterable) return data.isEmpty;
    if (data is Map) return data.isEmpty;
    if (data is String) return data.isEmpty;
    return false;
  }
}
