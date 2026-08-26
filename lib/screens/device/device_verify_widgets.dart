import 'package:flutter/material.dart';
import '../../i18n/app_strings.dart';
import '../../widgets/pressable_scale.dart';

/// RFC 8628 请求预览卡：请求方应用 + 申请权限范围。
///
/// 仅在服务端暴露了安全预览（client 名 + scopes 列表）时由页面渲染；
/// 图标用品牌主色 tint 容器承载，替代模板化 ListTile。
class DeviceRequestPreview extends StatelessWidget {
  final Map<String, dynamic> preview;

  const DeviceRequestPreview({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final clientName =
        preview['client_name']?.toString() ??
        preview['client_id']?.toString() ??
        '';
    final rawScopes = preview['scopes'];
    final scopes = rawScopes is List
        ? rawScopes
              .map<String>((scope) => scope.toString().trim())
              .where((scope) => scope.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final scopeSummary = scopes.join(', ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.devices_other, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(clientName, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            if (scopes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                scopes.length > 1
                    ? strings.requestedScopes(scopeSummary)
                    : context.tr('Scope'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                softWrap: true,
              ),
              const SizedBox(height: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scopes.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: scheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.lock_outline,
                            size: 17,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            scopes[index],
                            softWrap: true,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 批准/拒绝决策按钮：批准为主 CTA（loading spinner），拒绝为次级
/// （error 前景语义）。按钮带按压反馈与语义图标。
class DeviceDecisionButtons extends StatelessWidget {
  final bool busy;
  final bool checking;
  final VoidCallback? onDeny;
  final VoidCallback? onApprove;

  const DeviceDecisionButtons({
    super.key,
    required this.busy,
    required this.checking,
    required this.onDeny,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: PressableScale(
            child: OutlinedButton.icon(
              onPressed: busy ? null : onDeny,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.close, size: 18),
              label: Text(strings.deny),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PressableScale(
            child: FilledButton.icon(
              onPressed: busy ? null : onApprove,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: busy && !checking
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(strings.approve),
            ),
          ),
        ),
      ],
    );
  }
}

/// 状态块：spinner 或品牌主色图标 + 标题 + 可选副标题（loading/empty 态），
/// 对齐登录壳层 `_ShellStatus` 先例。
class DeviceStatusBlock extends StatelessWidget {
  final IconData? icon;
  final bool spinner;
  final String title;
  final String? subtitle;

  const DeviceStatusBlock({
    super.key,
    this.icon,
    this.spinner = false,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(icon, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 状态卡：图标 + 可换行文案（品牌/语义色），替代手写 `Text` +
/// `SizedBox` 模板。`contained` 变体用于错误——`errorContainer` 底 +
/// `onErrorContainer` 前景，与 consent/mfa 视图同风格。
class DeviceInlineNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final bool contained;
  final bool liveRegion;

  const DeviceInlineNotice({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    this.contained = false,
    this.liveRegion = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notice = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
    final wrapped = contained
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: notice,
          )
        : Card(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: notice,
            ),
          );
    return liveRegion ? Semantics(liveRegion: true, child: wrapped) : wrapped;
  }
}
