import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';

import '../../i18n/app_strings.dart';
import '../../widgets/pressable_scale.dart';

/// 通知型面板骨架：logo + 标题 + 提示条 + 操作按钮（已初始化/不可用共用）。
class SetupNoticePanel extends StatelessWidget {
  final String title;
  final SetupInlineNotice notice;
  final List<Widget> actions;

  const SetupNoticePanel({
    super.key,
    required this.title,
    required this.notice,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SetupLogo(),
      const SizedBox(height: 12),
      Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      notice,
      for (final action in actions) ...[const SizedBox(height: 12), PressableScale(child: action)],
    ],
  );
}

/// 初始化向导加载态：logo + spinner + 标题 + 副标题（loading 态带可见
/// 进度指示，替代原先纯文字）。
class SetupLoadingPanel extends StatelessWidget {
  const SetupLoadingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SetupLogo(),
        const SizedBox(height: 16),
        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
        const SizedBox(height: 16),
        Text(strings.setup, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          strings.checkingSystemStatus,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 已初始化终态：成功提示 + 前往控制台。
class SetupAlreadyInitializedPanel extends StatelessWidget {
  final VoidCallback onContinue;

  const SetupAlreadyInitializedPanel({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SetupNoticePanel(
      title: strings.alreadySetUp,
      notice: SetupInlineNotice(
        variant: SetupNoticeVariant.success,
        text: strings.alreadyInitialized,
      ),
      actions: [FilledButton(onPressed: onContinue, child: Text(strings.goToAdminConsole))],
    );
  }
}

/// 初始化不可用/状态未知：错误提示 + 重试 + 前往控制台。
class SetupUnavailablePanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  const SetupUnavailablePanel({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SetupNoticePanel(
      title: strings.setupUnavailableTitle,
      notice: SetupInlineNotice(text: message),
      actions: [
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(strings.retry),
        ),
        FilledButton(onPressed: onContinue, child: Text(strings.goToAdminConsole)),
      ],
    );
  }
}

/// 品牌 logo（初始化向导）：品牌渐变圆角块 + 白色钥匙图标，与
/// `BrandLogo` 同源视觉（渐变 + 投影）。
class SetupLogo extends StatelessWidget {
  const SetupLogo({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.violet],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: const Icon(Icons.vpn_key, color: Colors.white, size: 24),
  );
}

/// 两步进度条（管理员 → 应用）。
class SetupStepDots extends StatelessWidget {
  final int activeCount;

  const SetupStepDots({super.key, required this.activeCount});

  @override
  Widget build(BuildContext context) {
    Widget dot(bool on) => Container(
      width: 34,
      height: 4,
      decoration: BoxDecoration(
        color: on ? AppColors.primary : Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Semantics(
      label: AppStrings.of(context).stepOf(activeCount, 2),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [dot(activeCount >= 1), const SizedBox(width: 8), dot(activeCount >= 2)],
        ),
      ),
    );
  }
}

/// 可选标签（"Optional"）。
class SetupOptionalTag extends StatelessWidget {
  final String label;

  const SetupOptionalTag({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(8)),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.primaryDark,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// 内联提示条：图标 + 文案。error 变体 = errorContainer 底 +
/// onErrorContainer 前景（与 consent/mfa/login 先例一致）；success 变体 =
/// successTint 底 + successDark 前景（品牌语义色，对比度 ≥7）。替代手写
/// `Container + Text` 模板。
enum SetupNoticeVariant { error, success }

class SetupInlineNotice extends StatelessWidget {
  final String text;
  final SetupNoticeVariant variant;
  final bool liveRegion;

  const SetupInlineNotice({
    super.key,
    required this.text,
    this.variant = SetupNoticeVariant.error,
    this.liveRegion = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, iconColor, background, foreground) = switch (variant) {
      SetupNoticeVariant.error => (
        Icons.error_outline,
        scheme.error,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      SetupNoticeVariant.success => (
        Icons.check_circle_outline,
        AppColors.success,
        AppColors.successTint,
        AppColors.successDark,
      ),
    };
    final notice = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ),
      ],
    );
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: notice,
    );
    return liveRegion ? Semantics(liveRegion: true, child: box) : box;
  }
}

/// 凭据行：标签（一次性密钥带 "shown once" 标记）+ 复制按钮 + 深底等宽值。
class SetupCredentialValue extends StatelessWidget {
  final String label;
  final String value;
  final bool shownOnce;

  const SetupCredentialValue({
    super.key,
    required this.label,
    required this.value,
    this.shownOnce = false,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    showAppSnackBar(context, content: Text(AppStrings.of(context).copiedLabel(label)));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              shownOnce ? AppStrings.of(context).shownOnce(label) : label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            tooltip: AppStrings.of(context).copyLabel(label),
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_outlined, size: 19, color: AppColors.primary),
          ),
        ],
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace')),
      ),
    ],
  );
}

/// 完成页：一次性凭据展示 + 部分成功（应用缺失）恢复 + 离开门禁
/// （密钥需勾选已保存）。
class SetupDonePanel extends StatefulWidget {
  final String? adminUsername;
  final String? clientId;
  final String? clientSecret;
  final bool applicationRequestedButMissing;
  final Future<void> Function()? onRetryApplication;
  final bool busy;
  final VoidCallback onDone;

  const SetupDonePanel({
    super.key,
    this.adminUsername,
    this.clientId,
    this.clientSecret,
    this.applicationRequestedButMissing = false,
    this.onRetryApplication,
    this.busy = false,
    required this.onDone,
  });

  @override
  State<SetupDonePanel> createState() => _SetupDonePanelState();
}

class _SetupDonePanelState extends State<SetupDonePanel> {
  bool _savedSecret = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 72, color: AppColors.success),
        const SizedBox(height: 16),
        Semantics(container: true, header: true, child: Text(strings.setupComplete, style: Theme.of(context).textTheme.headlineMedium)),
        const SizedBox(height: 8),
        Text(strings.setupCompleteDescription),
        if (widget.adminUsername != null) ...[
          const SizedBox(height: 8),
          SetupCredentialValue(label: strings.administratorUsername, value: widget.adminUsername!),
        ],
        if (widget.applicationRequestedButMissing) ...[
          const SizedBox(height: 12),
          SetupInlineNotice(text: strings.setupApplicationMissing),
          if (widget.onRetryApplication != null) ...[
            const SizedBox(height: 8),
            PressableScale(
              child: OutlinedButton.icon(
                onPressed: widget.busy ? null : widget.onRetryApplication,
                icon: widget.busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(strings.retryApplicationCreation),
              ),
            ),
          ],
        ],
        if (widget.clientId != null) ...[
          const SizedBox(height: 8),
          SetupCredentialValue(label: strings.clientId, value: widget.clientId!),
        ],
        if (widget.clientSecret != null) ...[
          const SizedBox(height: 8),
          SetupCredentialValue(
            label: strings.clientSecret,
            value: widget.clientSecret!,
            shownOnce: true,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _savedSecret,
            onChanged: (value) => setState(() => _savedSecret = value ?? false),
            title: Text(strings.secretSavedConfirmation),
            subtitle: Text(strings.secretEraseWarning),
          ),
        ],
        const SizedBox(height: 32),
        PressableScale(
          child: FilledButton(
            onPressed: widget.clientSecret == null || _savedSecret ? widget.onDone : null,
            child: Text(strings.goToAdminConsole),
          ),
        ),
      ],
    );
  }
}
