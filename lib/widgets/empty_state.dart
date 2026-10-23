import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Empty-state variants: icon/title defaults per variant; title/subtitle/
/// icon remain overridable per call.
enum EmptyStateVariant { empty, noMatch, notEnabled, error }

/// Reusable empty state widget shown when a list or view has no data.
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Action-button leading icon; defaults to [Icons.add] (historical).
  /// "Clear filter" / "Retry" actions pass a semantic glyph instead.
  final IconData? actionIcon;

  /// Visual variant; `empty` == the historical default (copy preserved).
  final EmptyStateVariant variant;

  /// Compact sizing (icon container 48 / icon 22 / padding 24).
  final bool compact;

  const EmptyState({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.variant = EmptyStateVariant.empty,
    this.compact = false,
  });

  (IconData, String) get _variantDefaults => switch (variant) {
    EmptyStateVariant.empty => (Icons.inbox_outlined, 'No data'),
    EmptyStateVariant.noMatch => (Icons.search_off, 'No matches'),
    EmptyStateVariant.notEnabled => (
      Icons.toggle_off_outlined,
      'This feature is not enabled on the connected replica.',
    ),
    EmptyStateVariant.error => (Icons.error_outline, 'Error'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (defaultIcon, defaultTitle) = _variantDefaults;
    final resolvedIcon = icon ?? defaultIcon;
    final resolvedTitle = title ?? defaultTitle;
    final iconSize = compact ? 48.0 : 72.0;
    final iconContainer = Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 16 : 24),
      ),
      child: Icon(resolvedIcon, size: compact ? 22 : 32, color: scheme.primary),
    );
    final iconWidget = MediaQuery.disableAnimationsOf(context)
        ? iconContainer
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: 0.82 + 0.18 * value, child: child),
            child: iconContainer,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final basePadding = compact ? 24.0 : 32.0;
        final parentWidth = constraints.maxWidth;
        // Keep the icon at its variant size by giving up horizontal padding on
        // very narrow parents instead of squeezing/clipping the content.
        final horizontalPadding = parentWidth.isFinite
            ? math.min(basePadding, math.max(0.0, (parentWidth - iconSize) / 2))
            : basePadding;
        final contentWidth = parentWidth.isFinite
            ? parentWidth - horizontalPadding * 2
            : double.infinity;
        // `OutlinedButton.icon` keeps the icon and label in one row; below
        // this width, wrap them so narrow parents do not overflow.
        final narrowAction = contentWidth < 160;
        final action = actionLabel != null && onAction != null
            ? narrowAction
                  ? OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 40),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Icon(actionIcon ?? Icons.add, size: 18),
                          Text(
                            context.tr(actionLabel!),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: onAction,
                      icon: Icon(actionIcon ?? Icons.add, size: 18),
                      label: Text(context.tr(actionLabel!)),
                    )
            : null;
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: basePadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 品牌渐变圆底图标（Stripe/Supabase 风格空状态）+ 入场弹入。
                iconWidget,
                const SizedBox(height: 16),
                Text(
                  context.tr(resolvedTitle),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr(subtitle!),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 16), action],
              ],
            ),
          ),
        );
      },
    );
  }
}
