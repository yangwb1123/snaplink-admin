import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/hover_card.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Inline success/error banner, the Flutter equivalent of app.js's
/// `showMsg(el, text, ok)` (`<div class="msg err|ok">`) — green/red text,
/// hidden entirely (renders nothing) once there is no message to show.
class MessageBanner extends StatelessWidget {
  final String? text;
  final bool ok;
  const MessageBanner(this.text, {super.key, this.ok = false});

  @override
  Widget build(BuildContext context) {
    final t = text;
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    final color = ok ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.tr(t), style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

/// Muted placeholder text for an empty list — mirrors app.js's
/// `<div class="empty">…</div>`.
class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        context.tr(text),
        style: TextStyle(color: Colors.grey.shade500),
      ),
    );
  }
}

/// A labelled key/value line, the Flutter equivalent of app.js's
/// `<div class="kv"><span class="k">label</span><span>value</span></div>`
/// used on the profile summary. Label is literal copy (i18n key); value is
/// an API value rendered with [Text] (never routed through i18n).
class KvRow extends StatelessWidget {
  final String label;
  final String value;
  const KvRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              context.tr(label),
              style: dataEmphasisStyle(DataEmphasisLevel.tertiary, theme),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: dataEmphasisStyle(DataEmphasisLevel.secondary, theme),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section card wrapper matching the established dark-theme look (relies on
/// the app-wide ThemeData: AppColors.textMuted card surface via CardTheme,
/// brand AppColors.primary via ColorScheme) — every portal section renders
/// as one of these, same as app.js's `<div class="card">`.
class PortalCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const PortalCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      margin: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr(title),
                style: dataEmphasisStyle(
                  DataEmphasisLevel.secondary,
                  Theme.of(context),
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Overview 页 MFA 安全横幅：双表达（图标 + StatusChip 徽章），语义色编码
/// （success=已开启 / warning=未开启）。
class PortalSecurityBanner extends StatelessWidget {
  final bool mfaEnabled;
  const PortalSecurityBanner({super.key, required this.mfaEnabled});

  @override
  Widget build(BuildContext context) {
    final color = mfaEnabled ? AppColors.success : AppColors.warning;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            mfaEnabled
                ? Icons.verified_user_outlined
                : Icons.warning_amber_outlined,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LocalizedText(
              mfaEnabled
                  ? 'Account protected'
                  : 'Enable MFA to protect your account',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            label: context.tr(mfaEnabled ? 'MFA on' : 'MFA off'),
            color: color,
            icon: mfaEnabled ? Icons.shield : Icons.shield_outlined,
          ),
        ],
      ),
    );
  }
}

/// Overview 页账户指标卡（Stripe 风格）：活跃会话 / 已连接应用，品牌色图标。
class PortalMetricsStrip extends StatelessWidget {
  final int activeSessions;
  final int connectedApps;
  const PortalMetricsStrip({
    super.key,
    required this.activeSessions,
    required this.connectedApps,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return MetricStrip(
      cards: [
        KeyMetricCard(
          label: 'Active sessions',
          value: activeSessions,
          icon: Icons.devices_outlined,
          color: accent,
        ),
        KeyMetricCard(
          label: 'Connected apps',
          value: connectedApps,
          icon: Icons.apps_outlined,
          color: accent,
        ),
      ],
    );
  }
}

/// Overview 页授权摘要行：品牌色图标圆底 + 标题（API 值，Text 直渲）+
/// 可选 meta 说明。
class PortalAuthzRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String meta;
  const PortalAuthzRow({
    super.key,
    required this.icon,
    required this.title,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 整页加载失败态：统一 ErrorStateView（图标 + 标题 + 明细 + 重试）。
class PortalErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const PortalErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      margin: const EdgeInsets.all(24),
      child: ErrorStateView(message: message, onRetry: onRetry),
    ),
  );
}
