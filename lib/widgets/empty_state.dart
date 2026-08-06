import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Reusable empty state widget shown when a list or view has no data.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title = 'No data',
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 品牌渐变圆底图标（Stripe/Supabase 风格空状态）+ 入场弹入。
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Transform.scale(
              scale: 0.82 + 0.18 * value,
              child: child,
            ),
            child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.16),
                  scheme.primary.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
              child: Icon(icon, size: 32, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(title),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(subtitle!),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
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
