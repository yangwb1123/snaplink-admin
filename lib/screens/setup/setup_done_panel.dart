part of 'setup_widgets.dart';

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
        const Icon(
          Icons.check_circle_outline,
          size: 72,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        // R36：与其他 setup 面板标题（titleLarge）同层，消除全库唯一 headlineMedium 离群。
        Semantics(
          container: true,
          header: true,
          child: Text(
            strings.setupComplete,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Text(strings.setupCompleteDescription, textAlign: TextAlign.center),
        if (widget.adminUsername != null) ...[
          const SizedBox(height: 8),
          SetupCredentialValue(
            label: strings.administratorUsername,
            value: widget.adminUsername!,
          ),
        ],
        if (widget.applicationRequestedButMissing) ...[
          const SizedBox(height: 12),
          SetupInlineNotice(text: strings.setupApplicationMissing),
          if (widget.onRetryApplication != null) ...[
            const SizedBox(height: 8),
            PressableScale(
              child: OutlinedButton.icon(
                onPressed: widget.busy ? null : widget.onRetryApplication,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
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
          SetupCredentialValue(
            label: strings.clientId,
            value: widget.clientId!,
          ),
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
            onPressed: widget.clientSecret == null || _savedSecret
                ? widget.onDone
                : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: Text(strings.goToAdminConsole),
          ),
        ),
      ],
    );
  }
}
