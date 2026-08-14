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
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 24 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 品牌渐变圆底图标（Stripe/Supabase 风格空状态）+ 入场弹入。
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, value, child) =>
                  Transform.scale(scale: 0.82 + 0.18 * value, child: child),
              child: Container(
                width: compact ? 48 : 72,
                height: compact ? 48 : 72,
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
                child: Icon(
                  resolvedIcon,
                  size: compact ? 22 : 32,
                  color: scheme.primary,
                ),
              ),
            ),
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
