import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'empty_state.dart';
import 'skeleton_list.dart';

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

  /// Error-state headline; defaults to 'Failed to load' (see
  /// [ErrorStateView]). Page-specific titles (e.g. 'Failed to load user')
  /// can override it without forking the error layout.
  final String? errorTitle;

  final String? emptyTitle;
  final String? emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Widget Function(T data) dataBuilder;

  /// true = 列表页加载态用骨架屏（[SkeletonListTile]）替代加载圈。
  final bool useSkeleton;

  /// 骨架延迟显示时长（快速加载防闪）；默认零 = 立即显示。
  final Duration skeletonDelay;

  const AsyncView({
    super.key,
    required this.loading,
    this.error,
    this.data,
    this.onRetry,
    this.errorTitle,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
    required this.dataBuilder,
    this.useSkeleton = false,
    this.skeletonDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final loadingContent = useSkeleton
          ? TickerMode(
              enabled: !reduceMotion,
              child: SkeletonListTile(
                itemCount: 5,
                delay: reduceMotion ? Duration.zero : skeletonDelay,
              ),
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
      // SkeletonListTile already exposes the single loading live region for
      // its placeholder tree. Do not wrap it in a second live region, which
      // would announce loading twice to assistive technology.
      if (useSkeleton) return loadingContent;
      return Semantics(
        container: true,
        liveRegion: true,
        label: context.strings.loading,
        child: loadingContent,
      );
    }

    if (error != null) {
      return ErrorStateView(
        title: errorTitle,
        // Preserve source-string translations; unknown API/exception details
        // fall back verbatim in AppStrings.translate.
        message: context.tr(error!),
        onRetry: onRetry,
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

/// Full-page error state: icon + title + detail + Retry.
///
/// Single source of truth for the error branch of [AsyncView] and for
/// pages/tabs that manage their own three-state switch but must render the
/// same failure surface (detail screens, list tabs, portal tabs).
class ErrorStateView extends StatelessWidget {
  /// Headline; defaults to 'Failed to load' (already in the EN/ZH catalog).
  final String? title;

  /// Failure detail rendered under the headline. This is display text, not an
  /// i18n source key; API and exception details must remain verbatim.
  final String message;

  /// Optional retry action; omitting it hides the button.
  final VoidCallback? onRetry;

  /// Retry button label override (e.g. 'Retry discovery'); defaults to
  /// 'Retry' from the shared catalog.
  final String? retryLabel;

  const ErrorStateView({
    super.key,
    this.title,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              context.tr(title ?? 'Failed to load'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(
                  retryLabel == null
                      ? context.strings.retry
                      : context.tr(retryLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error banner: tinted card with icon + message (+ optional
/// headline) + Retry.
///
/// Unifies the tab-level "danger card + Retry" pattern (audit log, health,
/// webhooks, usage analytics, SCIM browser, live events, …) and the
/// workbench [ConnectionErrorCard] so every in-context failure surface
/// shares one implementation.
class ErrorStateCard extends StatelessWidget {
  /// Optional headline above the message (e.g. 'Cannot reach backend').
  final String? title;

  /// Failure detail rendered as the card body.
  final String message;

  /// Retry action; omitting it hides the button.
  final VoidCallback? onRetry;

  /// Disables the retry button while a reload is already in flight.
  final bool retryEnabled;

  /// Renders the message as [SelectableText] (copyable errors).
  final bool selectable;

  /// Card margin override; defaults to the [Card] theme margin.
  final EdgeInsetsGeometry? margin;

  const ErrorStateCard({
    super.key,
    this.title,
    required this.message,
    this.onRetry,
    this.retryEnabled = true,
    this.selectable = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final messageStyle = TextStyle(color: scheme.error);
    final messageWidget = selectable
        ? SelectableText(message, style: messageStyle)
        : Text(message, style: messageStyle);
    final detail = title == null
        ? messageWidget
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(title!),
                style: messageStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              messageWidget,
            ],
          );
    final retry = onRetry == null
        ? null
        : TextButton.icon(
            onPressed: retryEnabled ? onRetry : null,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.strings.retry),
          );
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.45),
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // SelectableText can become excessively tall when it shares a
            // very narrow horizontal Row with the action. Stack the action
            // below the detail on phones; the wider layout is unchanged.
            final narrow = constraints.maxWidth < 360;
            if (narrow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: scheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        detail,
                        if (retry != null) ...[
                          const SizedBox(height: 8),
                          retry,
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error),
                const SizedBox(width: 12),
                Expanded(child: detail),
                if (retry != null) ...[const SizedBox(width: 8), retry],
              ],
            );
          },
        ),
      ),
    );
  }
}
